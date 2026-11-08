# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Configures the client for a server-driven or a self-contained build.
        module RuntimeMode
          private

          def contribute_runtime_mode(build)
            configured = configure_client_runtime_mode(
              build.client_dir, self_contained: build.self_contained, verbose: build.verbose)
            return false if configured == false

            configure_native_apple_runtime(
              build.client_dir, platform: build.platform, self_contained: build.self_contained,
              config: build.config, verbose: build.verbose)
            configure_android_runtime(
              build.client_dir, platform: build.platform, self_contained: build.self_contained,
              verbose: build.verbose)
            true
          end

          def configure_client_runtime_mode(client_dir, self_contained:, verbose: false)
            build_log(verbose, "configuring #{self_contained ? 'self-contained' : 'server-driven'} runtime")
            if self_contained
              return false unless sync_self_contained_project_assets(client_dir, verbose: verbose)
              remove_local_ruby_runtime_override(client_dir, verbose: verbose)
            else
              remove_self_contained_project_assets(client_dir, verbose: verbose)
              remove_local_ruby_runtime_override(client_dir, verbose: verbose)
            end
            sync_client_pubspec_for_runtime_mode(client_dir, self_contained: self_contained)
            true
          end

          def sync_client_pubspec_for_runtime_mode(client_dir, self_contained:)
            pubspec_path = File.join(client_dir, "pubspec.yaml")
            return unless File.file?(pubspec_path)

            data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            dependencies = data["dependencies"]
            dependencies = data["dependencies"] = {} unless dependencies.is_a?(Hash)
            flutter = data["flutter"]
            flutter = data["flutter"] = {} unless flutter.is_a?(Hash)
            assets = Array(flutter["assets"]).map(&:to_s)
            project_prefix = "assets/#{self_contained_project_name}/"
            # The exact directory list changes between lite and full (most notably
            # vendor/bundle). Remove the previous profile's generated entries
            # before adding the directories that exist in this build.
            assets.reject! { |asset| asset == project_prefix || asset.start_with?(project_prefix) }

            if self_contained
              dependencies["ruby_runtime"] = ruby_runtime_dependency(dependencies["ruby_runtime"])
              # Flutter does not recurse into asset directories, so every subdirectory
              # of the embedded project (e.g. standalone_apps/<slug>/) must be listed
              # explicitly or its files never reach the bundle/manifest on device.
              self_contained_project_asset_dirs(client_dir).each do |dir_entry|
                assets << dir_entry unless assets.include?(dir_entry)
              end
            else
              dependencies.delete("ruby_runtime")
            end

            flutter["assets"] = assets unless assets.empty?
            flutter.delete("assets") if assets.empty?
            write_pubspec_yaml(pubspec_path, data)
          end

          def configure_native_apple_runtime(
            client_dir, platform:, self_contained:, config: {}, verbose: false
          )
            plist_paths = case platform.to_s
            when "ios", "ipa"
              [File.join(client_dir, "ios", "Runner", "Info.plist")]
            when "macos"
              [File.join(client_dir, "macos", "Runner", "Info.plist")]
            else
              []
            end

            plist_paths.each do |path|
              next unless File.file?(path)

              upsert_plist_string(
                path, "RufletEmbeddedProject",
                self_contained ? self_contained_project_name : "")
              upsert_plist_boolean(path, "RufletRuntimeAutostart", self_contained)
              upsert_plist_string(
                path, "RufletRuntimeProfile",
                self_contained ? embedded_runtime_profile.to_s : "")
              remove_plist_value(path, "RufletExperimentalNativeRenderer")
              apple_platform = platform.to_s == "ipa" ? "ios" : platform.to_s
              platform_config = platform_build_config(config, apple_platform)
              if platform_config["local_network"] == true
                # The embedded VM is in-process, but the application can still
                # explicitly connect to LAN services (for example RufletApp).
                description = platform_config["local_network_usage_description"].to_s.strip
                description = "Connect to Ruflet applications and services on your local network." if description.empty?
                upsert_plist_string(path, "NSLocalNetworkUsageDescription", description)
                upsert_plist_dictionary_boolean(
                  path, "NSAppTransportSecurity", "NSAllowsLocalNetworking", true)
              elsif self_contained
                remove_plist_value(path, "NSLocalNetworkUsageDescription")
                remove_plist_dictionary_boolean(
                  path, "NSAppTransportSecurity", "NSAllowsLocalNetworking")
              end
              message = if self_contained
                "native Apple runtime autostarts #{self_contained_project_name}"
              else
                "native Apple runtime uses the server URL resolved by Dart"
              end
              build_log(verbose, message)
            end
          end

          def configure_android_runtime(client_dir, platform:, self_contained:, verbose: false)
            return unless %w[apk android aab appbundle].include?(platform.to_s)

            path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
            return unless File.file?(path)

            upsert_android_metadata(path, "ruflet.runtime.autostart", self_contained.to_s)
            upsert_android_metadata(
              path, "ruflet.runtime.project",
              self_contained ? self_contained_project_name : "")
            upsert_android_metadata(
              path, "ruflet.runtime.profile",
              self_contained ? embedded_runtime_profile.to_s : "")
            build_log(
              verbose,
              self_contained ? "android runtime autostarts #{self_contained_project_name} (#{embedded_runtime_profile})" : "android embedded runtime autostart disabled"
            )
          end

          # Tells the platform layer to start the embedded runtime, and which
          # packaged project to run.
          #
          # This is platform configuration rather than a dart-define because the VM
          # starts before Dart does: on Apple platforms from the plugin's +load, on
          # Android from an androidx.startup provider. Neither can read a value that
          # only exists inside the Dart isolate.
          #
          # Desktop needs nothing here -- it has no manifest to carry a flag, and
          # treats the presence of a packaged project as the opt-in, which is the
          # same distinction this flag draws on the other platforms.
          def configure_platform_autostart(client_dir, platform, verbose: false)
            project = self_contained_project_name
            case platform
            when "ios", "macos"
              plist = File.join(client_dir, platform, "Runner", "Info.plist")
              return unless File.file?(plist)

              set_plist_value(plist, "RufletRuntimeAutostart", "bool", "true")
              set_plist_value(plist, "RufletEmbeddedProject", "string", project)
              build_log(verbose, "enabled runtime autostart in #{platform}/Runner/Info.plist")
            when "apk", "appbundle", "android"
              manifest = File.join(
                client_dir, "android", "app", "src", "main", "AndroidManifest.xml"
              )
              return unless File.file?(manifest)

              set_android_meta_data(manifest, "ruflet.runtime.autostart", "true")
              set_android_meta_data(manifest, "ruflet.runtime.project", project)
              build_log(verbose, "enabled runtime autostart in AndroidManifest.xml")
            end
          end

          def remove_local_ruby_runtime_override(client_dir, verbose: false)
            overrides_path = File.join(client_dir, "pubspec_overrides.yaml")
            return unless File.file?(overrides_path)

            File.delete(overrides_path)
            build_log(verbose, "removed ruby_runtime override")
          rescue StandardError => e
            warn "Failed to remove ruby_runtime override: #{e.class}: #{e.message}"
          end
        end

        register :runtime_mode, :contribute_runtime_mode
      end
    end
  end
end
