# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Refreshes the template-owned client files and verifies the pinned Ruflet
        # engine sources before anything else is written.
        module TemplateRefresh
          RUFLET_SOURCE_INTEGRITY_PATH = File.join(
            "tool", "conformance", "ruflet_source_integrity.json"
          ).freeze
          RUFLET_SOURCE_IGNORED_DIRECTORIES = %w[
            .git .dart_tool .cache build .pub-cache .idea .vscode coverage
          ].freeze
          RUFLET_SOURCE_IGNORED_FILES = %w[
            pubspec.lock .DS_Store .flutter-plugins .flutter-plugins-dependencies
          ].freeze

          private

          def refresh_managed_client_template_files(client_dir, platform: nil, verbose: false)
            template_root =
              if Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)
                Ruflet::CLI.send(:resolve_ruflet_client_template_root)
              end
            return unless template_root && Dir.exist?(template_root)
            return false unless validate_template_ruflet_source_integrity(
              template_root, verbose: verbose)

            managed_files = [
              "lib/main.dart",
              "lib/main.self.dart",
              "lib/main.server.dart",
              "lib/connection_probe.dart",
              "lib/connection_probe_io.dart",
              "lib/connection_probe_stub.dart",
              "ios/Podfile",
              # Carries the usage descriptions and the local-network/ATS policy a
              # preview client needs. Without refreshing it, a client generated
              # before those keys existed keeps a plist that silently blocks
              # connections to a development server on the local network.
              "ios/Runner/Info.plist",
              "windows/CMakeLists.txt",
              # Release signing lives here; an existing client would otherwise keep
              # signing release builds with the debug key.
              "android/app/build.gradle.kts"
            ]

            case platform.to_s
            when "ios", "ipa"
              managed_files.concat(
                [
                  "ios/Runner/AppDelegate.swift",
                  "ios/Runner.xcodeproj/project.pbxproj"
                ]
              )
            when "macos"
              managed_files.concat(
                [
                  "macos/Runner/MainFlutterWindow.swift",
                  "macos/Runner.xcodeproj/project.pbxproj"
                ]
              )
            end

            managed_files.each do |relative_path|
              source = File.join(template_root, relative_path)
              next unless File.file?(source)

              destination = File.join(client_dir, relative_path)
              FileUtils.mkdir_p(File.dirname(destination))
              FileUtils.cp(source, destination)
              build_log(verbose, "refreshed template file #{relative_path}")
            end

            # Older managed clients carried a macOS-only FilePicker override. Ruflet's
            # core service owns FilePicker now, so this duplicate must not survive a
            # template refresh.
            FileUtils.rm_f(File.join(client_dir, "lib", "ruflet_file_picker_service.dart"))
            true
          end

          # Every application build copies its engine and extension packages out of
          # the template. Validate the pinned inventory before that copy so a stale,
          # partially updated, or locally contaminated template can never become an
          # application dependency by accident.
          def validate_template_ruflet_source_integrity(template_root, verbose: false)
            packages_root = File.join(template_root, "ruflet_packages")
            return true unless Dir.exist?(packages_root)

            manifest_path = File.join(template_root, RUFLET_SOURCE_INTEGRITY_PATH)
            raise "missing #{RUFLET_SOURCE_INTEGRITY_PATH}" unless File.file?(manifest_path)

            manifest = JSON.parse(read_text_file(manifest_path))
            raise "unsupported source manifest version" unless manifest["manifest_version"] == 5
            raise "unexpected source package" unless manifest["package_name"] == "ruflet-engine"
            raise "invalid source revision" unless manifest["source_ref"].to_s.match?(/\A[0-9a-f]{40}\z/)

            files = manifest.fetch("files")
            raise "empty source inventory" unless files.is_a?(Hash) && !files.empty?

            actual = []
            Find.find(packages_root) do |path|
              next if path == packages_root

              relative = path.delete_prefix("#{packages_root}#{File::SEPARATOR}")
              if RUFLET_SOURCE_IGNORED_DIRECTORIES.include?(File.basename(path))
                Find.prune if File.directory?(path)
                next
              end
              next if RUFLET_SOURCE_IGNORED_FILES.include?(File.basename(path))
              next if File.directory?(path)
              raise "symbolic link in engine source: #{path}" if File.symlink?(path)

              actual << relative
            end
            expected = files.keys.sort
            unless actual.sort == expected
              missing = expected - actual
              unexpected = actual - expected
              details = []
              details << "missing: #{missing.first(5).join(', ')}" unless missing.empty?
              details << "unexpected: #{unexpected.first(5).join(', ')}" unless unexpected.empty?
              raise "source inventory mismatch (#{details.join('; ')})"
            end

            files.each do |relative, entry|
              path = File.expand_path(relative, packages_root)
              prefix = "#{File.expand_path(packages_root)}#{File::SEPARATOR}"
              raise "unsafe source path: #{relative}" unless path.start_with?(prefix)
              raise "source path mismatch: #{relative}" unless entry["source_path"] == relative
              raise "non-exact source entry: #{relative}" unless entry["classification"] == "exact_source"

              expected_sha = entry["vendored_sha256"].to_s
              raise "invalid source digest: #{relative}" unless expected_sha.match?(/\A[0-9a-f]{64}\z/)
              actual_sha = Digest::SHA256.file(path).hexdigest
              raise "source content drift: #{relative}" unless actual_sha == expected_sha
            end

            build_note(
              "Verified #{files.length} pinned Ruflet engine and extension source files " \
              "at #{manifest.fetch('source_ref')}"
            )
            true
          rescue StandardError => e
            warn "build config error: Ruflet template source verification failed: #{e.message}"
            build_log(verbose, "template source integrity failure at #{template_root}")
            false
          end
        end
      end
    end
  end
end
