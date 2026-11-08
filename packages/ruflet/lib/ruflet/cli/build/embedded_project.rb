# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Selects and packages the project files a self-contained build embeds.
      module EmbeddedProject
        # Anything embedded here is readable by anyone who unpacks the shipped
        # app, so signing keys and local environment files must never be copied
        # in even when a project keeps them beside its source.
        SECRET_ASSET_EXTENSIONS = %w[.p8 .p12 .pem .key .jks .keystore .mobileprovision].freeze
        SECRET_ASSET_BASENAMES = %w[.env .netrc key.properties].freeze

        # What a self-contained build actually needs from the project at runtime:
        # the entrypoint, the Ruby under lib/, and the assets that code loads by
        # path (image(src: "assets/logo.png"), lottie(...), fonts, audio).
        #
        # Everything else is already consumed by the time the app runs. Lite gems
        # are compiled into the VM; full-profile gems and lockfiles are staged by
        # package_full_runtime_gems instead of copied from the working tree.
        # ruflet.yaml and services.yaml have been turned into native configuration,
        # while tests, CI and store artwork were never runtime inputs. Listing
        # what belongs in rather than guessing what to leave out keeps unexpected
        # directories from being shipped --
        # release artwork once carried a lockfile that Apple read as an unsigned
        # code object and rejected the whole upload over.
        SELF_CONTAINED_PROJECT_ENTRYPOINT = "main.rb"
        SELF_CONTAINED_PROJECT_DIRECTORIES = %w[lib assets].freeze

        private

        # Flutter asset directory entries for every folder of the embedded project
        # that contains packaged files. Derived from the exact copy list so the
        # pubspec asset dirs match what sync_self_contained_project_assets writes.
        def self_contained_project_asset_dirs(client_dir = nil)
          prefix = "assets/#{self_contained_project_name}"
          dirs = project_asset_relative_paths.map { |rel| File.dirname(rel) }.uniq
          if client_dir
            packaged_root = File.join(client_dir, prefix)
            if Dir.exist?(packaged_root)
              Find.find(packaged_root) do |path|
                next unless File.file?(path)

                relative = Pathname.new(path).relative_path_from(Pathname.new(packaged_root)).to_s
                dirs << File.dirname(relative)
              end
            end
          end
          project_dirs = dirs.map { |dir| dir == "." ? "#{prefix}/" : "#{prefix}/#{dir}/" }
          manifest = File.join(client_dir.to_s, prefix, ".ruflet-runtime.json")
          project_dirs << "#{prefix}/.ruflet-runtime.json" if client_dir && File.file?(manifest)
          project_dirs.uniq.sort
        end

        def sync_self_contained_project_assets(client_dir, verbose: false)
          project_root = Pathname.new(Dir.pwd)
          assets_root = File.join(client_dir, "assets")
          destination_root = File.join(assets_root, self_contained_project_name)
          FileUtils.rm_rf(destination_root)
          FileUtils.mkdir_p(destination_root)

          copied = 0
          project_asset_relative_paths.each do |relative_path|
            source = project_root.join(relative_path)
            next unless source.exist? && source.file?

            destination = File.join(destination_root, relative_path)
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(source.to_s, destination)
            copied += 1
          end

          profile = embedded_runtime_profile
          if profile == :full
            return false unless package_full_runtime_gems(
              project_root, destination_root, client_dir, verbose: verbose)
          else
            return false unless precompile_lite_runtime_project(
              destination_root, verbose: verbose)
          end
          write_embedded_runtime_manifest(
            project_root, destination_root, profile: profile,
            platform: @ruflet_build_platform)

          build_log(verbose, "copied #{copied} project file#{copied == 1 ? '' : 's'} to assets/#{self_contained_project_name}")
          true
        end

        def remove_self_contained_project_assets(client_dir, verbose: false)
          assets_root = File.join(client_dir, "assets")
          removed = false

          project_root = File.join(assets_root, self_contained_project_name)
          if Dir.exist?(project_root)
            FileUtils.rm_rf(project_root)
            removed = true
          end

          build_log(verbose, "removed embedded self-contained project assets") if removed
        end

        def project_asset_relative_paths
          root = Pathname.new(Dir.pwd)
          included = []

          Find.find(root.to_s) do |path|
            pathname = Pathname.new(path)
            relative = pathname.relative_path_from(root).to_s
            next if relative.empty? || relative == "."

            if pathname.directory?
              if skip_project_asset_directory?(relative)
                Find.prune
                next
              else
                next
              end
            end

            next unless include_project_asset_file?(relative)

            included << relative
          end

          included.sort
        end

        def self_contained_project_name
          name = File.basename(Dir.pwd.to_s)
          name = "app" if name.to_s.strip.empty?
          name
        end

        def skip_project_asset_directory?(relative)
          excluded_directories = %w[
            .git
            .bundle
            .dart_tool
            .idea
            .ruby-lsp
            .vscode
            build
            coverage
            credentials
            fastlane
            log
            node_modules
            pkg
            ruflet_client
            tmp
            vendor
          ]
          relative.split(File::SEPARATOR).any? do |component|
            component.start_with?(".") || excluded_directories.include?(component)
          end
        end

        def secret_project_asset?(relative)
          basename = File.basename(relative)
          return true if SECRET_ASSET_BASENAMES.include?(basename)
          return true if basename.start_with?(".env.") && basename != ".env.example"
          return true if SECRET_ASSET_EXTENSIONS.include?(File.extname(basename).downcase)
          return true if basename.match?(/\Agoogle-play.*\.json\z/i)

          false
        end

        def include_project_asset_file?(relative)
          basename = File.basename(relative)
          return false if basename == ".DS_Store"

          unless self_contained_project_path?(relative)
            return false
          end

          if secret_project_asset?(relative)
            build_note("Excluded #{relative} from the embedded project; it looks like a credential")
            return false
          end
          true
        end

        def self_contained_project_path?(relative)
          return true if relative == SELF_CONTAINED_PROJECT_ENTRYPOINT

          top = relative.split(File::SEPARATOR).first
          SELF_CONTAINED_PROJECT_DIRECTORIES.include?(top)
        end
      end
    end
  end
end
