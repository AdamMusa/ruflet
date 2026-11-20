# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Finds, bootstraps and refreshes the managed Flutter client under
      # build/client, and clears its stale build state.
      module ClientDir
        private

        def ensure_flutter_client_dir(verbose: false)
          client_dir = detect_flutter_client_dir
          if client_dir
            if File.expand_path(client_dir) == File.expand_path(hidden_flutter_client_dir) &&
                !valid_flutter_client_root?(client_dir) &&
                !File.file?(File.join(client_dir, ".metadata"))
              if Ruflet::CLI.respond_to?(:copy_ruflet_client_template, true)
                Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
                client_dir = hidden_flutter_client_dir
                build_log(verbose, "repaired invalid managed Flutter client root")
              end
            end
            refresh_hidden_flutter_client_template(client_dir, verbose: verbose)
            return client_dir
          end

          bootstrapped = bootstrap_flutter_client_template
          build_log(verbose, "bootstrapped client template at #{bootstrapped}") if bootstrapped
          bootstrapped
        end

        def valid_flutter_client_root?(path)
          File.file?(File.join(path, "pubspec.yaml")) &&
            File.file?(File.join(path, "lib", "main.dart"))
        end

        def refresh_hidden_flutter_client_template(client_dir, verbose: false)
          return unless File.expand_path(client_dir) == File.expand_path(hidden_flutter_client_dir)
          return unless File.file?(File.join(client_dir, ".metadata"))
          return unless Ruflet::CLI.respond_to?(:resolve_ruflet_client_template_root, true)

          template_root = Ruflet::CLI.send(:resolve_ruflet_client_template_root)
          return unless template_root && Dir.exist?(template_root)
          return if Ruflet::CLI.respond_to?(:client_template_current?, true) &&
            Ruflet::CLI.send(:client_template_current?, client_dir, template_root)

          Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
          build_log(verbose, "refreshed managed Flutter client from template #{template_root}")
        end

        def detect_flutter_client_dir
          env_dir = ENV["RUFLET_CLIENT_DIR"]
          return env_dir if env_dir && Dir.exist?(env_dir)

          hidden = hidden_flutter_client_dir
          return hidden if Dir.exist?(hidden)

          local = File.expand_path("ruflet_client", Dir.pwd)
          return local if Dir.exist?(local)

          template = File.expand_path("templates/ruflet_flutter_template", Dir.pwd)
          return template if Dir.exist?(template)

          nil
        end

        def bootstrap_flutter_client_template
          return nil if ENV["RUFLET_CLIENT_DIR"]

          target = hidden_flutter_client_dir
          return target if Dir.exist?(target)

          if Ruflet::CLI.respond_to?(:copy_ruflet_client_template, true)
            Ruflet::CLI.send(:copy_ruflet_client_template, Dir.pwd)
          end

          Dir.exist?(target) ? target : nil
        end

        def ensure_ruflet_build_assets(force: false, verbose: false)
          return true unless respond_to?(:download_ruflet_assets, true)

          !!send(:download_ruflet_assets, force: force, verbose: verbose)
        rescue StandardError => e
          build_log(verbose, "ruflet asset bootstrap skipped: #{e.class}: #{e.message}")
          false
        end

        def hidden_flutter_client_dir(root = Dir.pwd)
          File.join(root, "build", "client")
        end

        def user_build_root(root = Dir.pwd)
          File.join(root, "build")
        end

        def clear_flutter_build_state(client_dir, verbose: false)
          flutter_build_dir = File.join(client_dir, ".dart_tool", "flutter_build")
          return unless Dir.exist?(flutter_build_dir)

          FileUtils.rm_rf(flutter_build_dir)
          build_log(verbose, "cleared .dart_tool/flutter_build")
        end

        def clear_stale_platform_outputs(client_dir, platform, verbose: false)
          stale_paths = case platform
          when "ios"
            %w[
              build/ios/Debug-iphonesimulator
              build/ios/iphonesimulator
            ]
          when "android", "apk", "aab"
            # Flutter and Gradle merge assets incrementally. When a build switches
            # from full to lite, removed project gems can otherwise survive in the
            # next APK even though pubspec.yaml and the source asset tree are clean.
            %w[
              build/app/intermediates/flutter
              build/app/intermediates/assets
              build/app/intermediates/compressed_assets
              build/app/intermediates/incremental/mergeReleaseAssets
            ]
          else
            []
          end

          stale_paths.each do |relative_path|
            path = File.join(client_dir, relative_path)
            next unless Dir.exist?(path)

            FileUtils.rm_rf(path)
            build_log(verbose, "cleared stale #{relative_path}")
          end

          return unless platform == "ios"

          # Xcode's incremental App.framework copy does not remove files that
          # disappeared from a Flutter asset directory. Clear only the generated
          # embedded project tree so a removed gem/archive cannot survive the
          # next signed build; native compilation outputs remain reusable.
          asset_pattern = File.join(
            client_dir, "build", "ios", "**", "flutter_assets", "assets",
            self_contained_project_name)
          Dir.glob(asset_pattern).each do |asset_root|
            next unless Dir.exist?(asset_root)

            FileUtils.rm_rf(asset_root)
            relative_path = Pathname.new(asset_root).relative_path_from(Pathname.new(client_dir))
            build_log(verbose, "cleared stale #{relative_path}")
          end
        end

        def client_entrypoint_paths(client_dir)
          %w[main.dart main.self.dart main.server.dart].map do |name|
            File.join(client_dir, "lib", name)
          end
        end

        def flutter_target_entrypoint(client_dir, self_contained:)
          candidate = File.join(
            client_dir,
            "lib",
            self_contained ? "main.self.dart" : "main.server.dart"
          )
          return nil unless File.file?(candidate)

          File.join("lib", File.basename(candidate))
        end
      end
    end
  end
end
