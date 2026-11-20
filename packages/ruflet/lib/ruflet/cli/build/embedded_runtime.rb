# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Resolves and packages the embedded Ruby runtime (lite mruby or full
      # CRuby) of a self-contained build.
      module EmbeddedRuntime
        EMBEDDED_RUNTIME_PROFILES = %i[lite full].freeze
        FULL_RUNTIME_MANIFEST = "ruflet-full-runtime.json"
        FULL_RUNTIME_BUNDLE_SCHEMA = 3

        # A self-contained build needs the embedded VM. Prefer a local checkout so
        # the runtime under development is the one packaged, and otherwise resolve
        # the published package.
        # 0.0.13 is the first release where the platform layer starts the VM and
        # exposes serverUrl(); the client entrypoint calls it, so an older runtime
        # would not build.
        PUBLISHED_RUBY_RUNTIME_CONSTRAINT = "^0.0.14"

        private

        # CocoaPods can incorrectly treat the static-library XCFramework copy
        # phase as up to date after Ruflet clears Debug-iphonesimulator. The
        # Runner then links with -lruflet_vm while the selected simulator slice
        # is absent. Stage that deterministic slice before Flutter invokes
        # Xcode; CocoaPods may still copy over it normally.
        def stage_ios_simulator_ruby_runtime(client_dir, build_args, verbose: false)
          return true unless build_args.include?("ios")
          return true unless build_args.include?("--simulator")

          runtime_root = if embedded_runtime_profile == :full
            @ruflet_full_runtime_path
          else
            explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
          end
          return true unless runtime_root

          source = File.join(
            runtime_root,
            "ios",
            "Frameworks",
            "RufletVM.xcframework",
            "ios-arm64_x86_64-simulator"
          )
          library = File.join(source, "libruflet_vm.a")
          return true unless File.file?(library)

          destination = File.join(
            client_dir,
            "build",
            "ios",
            "Debug-iphonesimulator",
            "XCFrameworkIntermediates",
            "ruby_runtime"
          )
          FileUtils.mkdir_p(destination)
          FileUtils.cp(library, File.join(destination, "libruflet_vm.a"))

          headers = File.join(source, "Headers")
          if Dir.exist?(headers)
            destination_headers = File.join(destination, "Headers")
            FileUtils.rm_rf(destination_headers)
            FileUtils.cp_r(headers, destination_headers)
          end

          build_log(verbose, "staged iOS simulator Ruflet VM at #{destination}")
          true
        end

        def ruby_runtime_dependency(current_dependency = nil)
          if embedded_runtime_profile == :full && @ruflet_full_runtime_path
            return { "path" => @ruflet_full_runtime_path }
          end

          local_path = explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
          return { "path" => local_path } if local_path

          current_dependency || PUBLISHED_RUBY_RUNTIME_CONSTRAINT
        end

        def configure_full_runtime_distribution(config, platform, verbose: false)
          configured = ENV["RUFLET_FULL_RUNTIME_PATH"].to_s.strip
          build_config = config["build"].is_a?(Hash) ? config["build"] : {}
          configured = build_config["full_runtime_path"].to_s.strip if configured.empty?
          candidates = []
          candidates << File.expand_path(configured, Dir.pwd) unless configured.empty?
          local_runtime = explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
          candidates << local_runtime if local_runtime

          candidates.compact.uniq.each do |root|
            manifest_path = File.join(root, FULL_RUNTIME_MANIFEST)
            pubspec_path = File.join(root, "pubspec.yaml")
            next unless File.file?(manifest_path) && File.file?(pubspec_path)

            manifest = JSON.parse(read_text_file(manifest_path))
            next unless manifest["engine"] == "cruby"
            platforms = Array(manifest["platforms"]).map(&:to_s)
            target = normalized_runtime_platform(platform)
            next unless platforms.include?(target)

            pubspec = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            next unless pubspec["name"] == "ruby_runtime"

            @ruflet_full_runtime_path = File.expand_path(root)
            @ruflet_full_runtime_manifest = manifest
            build_log(
              verbose,
              "full CRuby runtime=#{@ruflet_full_runtime_path} ruby=#{manifest['ruby_version']}"
            )
            return true
          rescue JSON::ParserError, Psych::SyntaxError => e
            build_log(verbose, "ignored invalid full runtime at #{root}: #{e.message}")
          end

          warn "build config error: --full needs a CRuby runtime distribution for #{normalized_runtime_platform(platform)}"
          warn "Set RUFLET_FULL_RUNTIME_PATH to a ruby_runtime Flutter package containing #{FULL_RUNTIME_MANIFEST}."
          warn "The bundled ruby_runtime is the lite mruby engine and will not be mislabeled as CRuby."
          false
        end

        def full_runtime_device_only?
          embedded_runtime_profile == :full &&
            @ruflet_full_runtime_manifest.is_a?(Hash) &&
            @ruflet_full_runtime_manifest["device_only"] == true
        end

        def normalized_runtime_platform(platform)
          return "android" if %w[apk android aab appbundle].include?(platform.to_s)
          return "ios" if %w[ios ipa].include?(platform.to_s)

          platform.to_s
        end

        def explicit_local_ruby_runtime_path
          env_path = ENV["RUFLET_RUBY_RUNTIME_PATH"].to_s.strip
          return nil if env_path.empty?

          candidate = Pathname.new(env_path).expand_path
          return candidate.to_s if candidate.join("pubspec.yaml").file?

          nil
        end

        # This file sits in lib/ruflet/cli/build/, so the checkout root is six
        # directories up.
        def source_checkout_ruby_runtime_path
          candidate = Pathname.new(File.expand_path("../../../../../../ruby_runtime", __dir__))
          return candidate.to_s if candidate.join("pubspec.yaml").file?

          nil
        end

        def precompile_lite_runtime_project(destination_root, verbose: false)
          compiler = embedded_mrbc_path
          unless compiler
            build_log(verbose, "mrbc unavailable; packaging lite Ruby source")
            return true
          end

          sources = Dir.glob(File.join(destination_root, "**", "*.rb")).sort
          compiled = []
          sources.each do |source|
            output = source.sub(/\.rb\z/, ".mrb")
            ok = run_external_command(
              {}, compiler, "-g", "-o", output, source,
              chdir: destination_root, unbundled: true)
            unless ok
              warn "Could not precompile #{Pathname.new(source).relative_path_from(Pathname.new(destination_root))} for --lite"
              return false
            end
            compiled << [source, output]
          end
          compiled.each { |source, _output| FileUtils.rm_f(source) }
          build_log(verbose, "precompiled #{compiled.length} Ruby file#{compiled.length == 1 ? '' : 's'} for fast lite startup")
          true
        end

        def embedded_mrbc_path
          explicit = ENV["RUFLET_MRBC"].to_s.strip
          return explicit if !explicit.empty? && File.executable?(explicit)

          runtime_root = explicit_local_ruby_runtime_path || source_checkout_ruby_runtime_path
          candidates = []
          if runtime_root
            candidates.concat(
              %w[host_vm host].map do |build|
                File.join(runtime_root, "third_party", "mruby", "build", build, "bin", "mrbc")
              end
            )
            candidates << File.join(runtime_root, "bin", "mrbc")
          end
          candidates.find { |path| File.executable?(path) }
        end

        def embedded_runtime_profile
          profile = @ruflet_runtime_profile
          EMBEDDED_RUNTIME_PROFILES.include?(profile) ? profile : :lite
        end

        # A full build carries the locked application bundle alongside the
        # project. Bundler is isolated under build/client so this never creates or
        # rewrites .bundle state in the user's project. The cache key makes repeat
        # builds cheap: unchanged locks reuse the installed bundle and only copy
        # it into the Flutter asset tree.
        def package_full_runtime_gems(project_root, destination_root, client_dir, verbose: false)
          gemfile = project_root.join("Gemfile")
          return true unless gemfile.file?

          lockfile = project_root.join("Gemfile.lock")
          unless lockfile.file?
            warn "full runtime build requires Gemfile.lock"
            warn "Run `bundle install` once so Ruflet can package a reproducible gem set."
            return false
          end

          cache_key = Digest::SHA256.hexdigest(
            [
              gemfile.read,
              lockfile.read,
              RUBY_ENGINE,
              RUBY_VERSION,
              @ruflet_build_platform.to_s,
              FULL_RUNTIME_BUNDLE_SCHEMA,
              JSON.generate(@ruflet_full_runtime_manifest || {})
            ].join("\0")
          )
          cache_root = File.join(client_dir, ".ruflet", "full-bundle", cache_key)
          bundle_path = File.join(cache_root, "vendor", "bundle")
          complete_marker = File.join(cache_root, ".complete")

          unless File.file?(complete_marker) && Dir.exist?(bundle_path)
            FileUtils.rm_rf(cache_root)
            FileUtils.mkdir_p(cache_root)
            bundle_env = {
              "BUNDLE_GEMFILE" => gemfile.to_s,
              "BUNDLE_PATH" => bundle_path,
              "BUNDLE_APP_CONFIG" => File.join(cache_root, "config"),
              "BUNDLE_WITHOUT" => "development:test",
              "BUNDLE_FROZEN" => "true",
              "BUNDLE_DEPLOYMENT" => "true"
            }
            build_note("Packaging locked project gems for the full CRuby runtime")
            build_log(verbose, "bundle cache=#{cache_root}")
            ok = run_full_runtime_gem_packager(
              bundle_env, gemfile: gemfile, lockfile: lockfile,
              bundle_path: bundle_path, project_root: project_root)
            unless ok
              warn "Could not package the locked project gems for --full"
              return false
            end
            unless vendor_full_runtime_path_gems(
              bundle_env, bundle_path: bundle_path, project_root: project_root)
              return false
            end
            prune_full_runtime_bundle_cache(bundle_path)
            return false unless validate_full_runtime_in_process_transport(bundle_path)
            File.write(complete_marker, "#{cache_key}\n")
          else
            build_log(verbose, "reusing full runtime gem cache #{cache_key[0, 12]}")
            return false unless validate_full_runtime_in_process_transport(bundle_path)
          end

          packaged_bundle = File.join(destination_root, "vendor", "bundle")
          FileUtils.mkdir_p(File.dirname(packaged_bundle))
          FileUtils.cp_r(bundle_path, packaged_bundle)
          FileUtils.cp(gemfile.to_s, File.join(destination_root, "Gemfile"))
          FileUtils.cp(lockfile.to_s, File.join(destination_root, "Gemfile.lock"))
          true
        rescue StandardError => e
          warn "Could not package project gems for --full: #{e.class}: #{e.message}"
          false
        end

        def run_full_runtime_gem_packager(bundle_env, gemfile:, lockfile:, bundle_path:, project_root:)
          packager = @ruflet_full_runtime_manifest && @ruflet_full_runtime_manifest["gem_packager"]
          unless packager.to_s.strip.empty?
            executable = File.expand_path(packager.to_s, @ruflet_full_runtime_path)
            unless File.executable?(executable)
              warn "Full runtime gem packager is not executable: #{executable}"
              return false
            end
            return run_external_command(
              bundle_env,
              executable,
              "--gemfile", gemfile.to_s,
              "--lockfile", lockfile.to_s,
              "--path", bundle_path,
              "--platform", normalized_runtime_platform(@ruflet_build_platform),
              chdir: project_root.to_s,
              unbundled: true
            )
          end

          run_external_command(
            bundle_env, RbConfig.ruby, "-S", "bundle", "install",
            "--jobs", "4", "--retry", "3",
            chdir: project_root.to_s, unbundled: true
          )
        end

        # Bundler intentionally leaves `path:` gems at their source location,
        # even when BUNDLE_PATH is set. A self-contained app cannot retain those
        # workstation paths. Materialize every resolved spec that sits outside
        # vendor/bundle so the runtime sees the exact locked source tree.
        def vendor_full_runtime_path_gems(bundle_env, bundle_path:, project_root:)
          script = <<~'RUBY'
            require "bundler"
            require "json"
            puts JSON.generate(Bundler.load.specs.map { |spec|
              {
                "full_name" => spec.full_name,
                "full_gem_path" => spec.full_gem_path,
                "extension_dir" => spec.extension_dir,
                "source_type" => spec.source.class.name,
                "files" => spec.files,
                "gemspec" => spec.to_ruby
              }
            })
          RUBY
          stdout, stderr, status = Open3.capture3(
            bundle_env, RbConfig.ruby, "-e", script,
            chdir: project_root.to_s)
          unless status.success?
            warn "Could not inspect locked project gems for --full"
            warn stderr unless stderr.to_s.strip.empty?
            return false
          end

          ruby_abi = (@ruflet_full_runtime_manifest || {})["ruby_abi"].to_s
          ruby_abi = RbConfig::CONFIG.fetch("ruby_version") if ruby_abi.empty?
          installed_root = File.expand_path(bundle_path)
          specs = JSON.parse(stdout)
          specs.each do |spec|
            next unless spec.fetch("source_type") == "Bundler::Source::Path"

            source = File.expand_path(spec.fetch("full_gem_path"))
            next if source == installed_root || source.start_with?("#{installed_root}#{File::SEPARATOR}")

            full_name = spec.fetch("full_name")
            destination = File.join(bundle_path, "ruby", ruby_abi, "gems", full_name)
            FileUtils.rm_rf(destination)
            FileUtils.mkdir_p(File.dirname(destination))
            unless copy_full_runtime_gem_files(
              source, destination, spec.fetch("files"), full_name: full_name)
              return false
            end

            specifications = File.join(bundle_path, "ruby", ruby_abi, "specifications")
            FileUtils.mkdir_p(specifications)
            File.write(File.join(specifications, "#{full_name}.gemspec"), spec.fetch("gemspec"))

            extension_source = spec["extension_dir"].to_s
            next unless !extension_source.empty? && Dir.exist?(extension_source)

            extension_destination = File.join(
              bundle_path, "ruby", ruby_abi, "extensions", "ruflet", full_name)
            FileUtils.rm_rf(extension_destination)
            FileUtils.mkdir_p(File.dirname(extension_destination))
            FileUtils.cp_r(extension_source, extension_destination)
          end
          true
        rescue JSON::ParserError, KeyError, SystemCallError => e
          warn "Could not vendor path gems for --full: #{e.class}: #{e.message}"
          false
        end

        # Downloaded .gem archives are installation inputs, not runtime inputs.
        # Keeping them would duplicate every registry gem in the application.
        def prune_full_runtime_bundle_cache(bundle_path)
          Dir.glob(File.join(bundle_path, "ruby", "*", "cache")).each do |cache_dir|
            FileUtils.rm_rf(cache_dir)
          end
        end

        # Full self builds cannot fall back to a local socket: the embedded
        # renderer and CRuby VM communicate only through the native in-memory
        # bridge. Reject an older locked ruflet_server while the app is still
        # being built instead of shipping a bundle that fails on first launch.
        def validate_full_runtime_in_process_transport(bundle_path)
          server_roots = Dir.glob(
            File.join(bundle_path, "ruby", "*", "gems", "ruflet_server-*")
          ).select { |path| Dir.exist?(path) }
          return true if server_roots.empty?

          supported = server_roots.any? do |root|
            File.file?(
              File.join(root, "lib", "ruflet", "server", "in_process_connection.rb")
            )
          end
          return true if supported

          warn "The locked ruflet_server gem does not support port-free --self --full builds."
          warn "Update the application's Gemfile.lock to a Ruflet release with in-process transport."
          false
        end

        # A path gem is a source checkout, not an installable payload. Copy only
        # the files declared by its gemspec so build products, tests, caches and
        # other workstation state cannot leak into a mobile application bundle.
        def copy_full_runtime_gem_files(source, destination, files, full_name:)
          source_root = File.expand_path(source)
          destination_root = File.expand_path(destination)
          declared_files = Array(files).map(&:to_s).reject(&:empty?).uniq.sort
          if declared_files.empty?
            warn "Could not vendor path gem #{full_name}: its gemspec declares no files"
            return false
          end

          declared_files.each do |relative_path|
            pathname = Pathname.new(relative_path)
            clean_path = pathname.cleanpath
            if pathname.absolute? || clean_path.each_filename.include?("..")
              warn "Could not vendor path gem #{full_name}: unsafe file path #{relative_path.inspect}"
              return false
            end

            source_file = File.expand_path(clean_path.to_s, source_root)
            unless source_file.start_with?("#{source_root}#{File::SEPARATOR}") && File.file?(source_file)
              warn "Could not vendor path gem #{full_name}: declared file is missing: #{relative_path}"
              return false
            end

            destination_file = File.expand_path(clean_path.to_s, destination_root)
            FileUtils.mkdir_p(File.dirname(destination_file))
            FileUtils.cp(source_file, destination_file, preserve: true)
          end
          true
        rescue SystemCallError => e
          warn "Could not vendor path gem #{full_name}: #{e.class}: #{e.message}"
          false
        end

        def write_embedded_runtime_manifest(project_root, destination_root, profile:, platform:)
          paths = Dir.glob(File.join(destination_root, "**", "*"), File::FNM_DOTMATCH)
            .select { |path| File.file?(path) }
            .reject { |path| File.basename(path) == ".ruflet-runtime.json" }
            .sort
          digest = Digest::SHA256.new
          paths.each do |path|
            relative = Pathname.new(path).relative_path_from(Pathname.new(destination_root)).to_s
            digest << relative << "\0" << File.binread(path) << "\0"
          end

          manifest = {
            "schema" => 1,
            "profile" => profile.to_s,
            "engine" => profile == :full ? "cruby" : "mruby",
            "platform" => platform.to_s,
            "project" => project_root.basename.to_s,
            "entrypoint" => File.file?(File.join(destination_root, "main.mrb")) ? "main.mrb" : "main.rb",
            "bundle_gemfile" => profile == :full && File.file?(File.join(destination_root, "Gemfile")) ? "Gemfile" : nil,
            "bundle_path" => profile == :full && Dir.exist?(File.join(destination_root, "vendor", "bundle")) ? "vendor/bundle" : nil,
            "cache_key" => digest.hexdigest,
            "warm_launch" => true
          }.compact
          File.write(
            File.join(destination_root, ".ruflet-runtime.json"),
            "#{JSON.pretty_generate(manifest)}\n"
          )
        end
      end
    end
  end
end
