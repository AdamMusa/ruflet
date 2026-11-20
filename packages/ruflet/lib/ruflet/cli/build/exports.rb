# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Copies built app outputs from build/client to build/<platform>, and back
      # for `ruflet install`, which also checks they can be installed.
      module Exports
        private

        def inferred_install_platform
          host_os = RbConfig::CONFIG["host_os"]
          return "ios" if host_os.match?(/darwin/i)

          nil
        end

        def export_platform_build_outputs(client_dir, platform, verbose: false)
          exports_for(platform).each do |relative_source, relative_target|
            source = File.join(client_dir, "build", relative_source)
            next unless File.exist?(source)

            target = File.join(user_build_root, relative_target)
            FileUtils.rm_rf(target)
            FileUtils.mkdir_p(File.dirname(target))
            FileUtils.cp_r(source, target)
            build_log(verbose, "exported #{source} -> #{target}")
          end
        end

        def sync_built_outputs_for_install(client_dir, platform: nil, verbose: false)
          synced = false

          platforms =
            if platform
              install_sync_platforms(platform)
            else
              %w[android ios macos windows linux web apk aab appbundle]
            end

          platforms.each do |target_platform|
            exports_for(target_platform).each do |relative_source, relative_target|
              source = File.join(user_build_root, relative_target)
              next unless File.exist?(source)

              target = File.join(client_dir, "build", relative_source)
              FileUtils.rm_rf(target)
              FileUtils.mkdir_p(File.dirname(target))
              FileUtils.cp_r(source, target)
              build_log(verbose, "synced #{source} -> #{target}")
              synced = true
            end
          end

          synced
        end

        def install_sync_platforms(platform)
          case platform
          when "ios"
            %w[ios]
          when "android"
            %w[android apk aab appbundle]
          when "macos"
            %w[macos]
          when "windows"
            %w[windows]
          when "linux"
            %w[linux]
          when "web"
            %w[web]
          else
            []
          end
        end

        def install_platform_for_device(device_id)
          return inferred_install_platform unless device_id

          return "android" if device_id.include?("emulator-") || device_id.match?(/\A[a-z0-9._:-]+\z/i) && device_id != "macos" && device_id != "chrome" && !device_id.include?("-")
          return "ios" if device_id.match?(/\A[0-9A-F-]{8,}\z/i)
          return "macos" if device_id == "macos"
          return "web" if device_id == "chrome"

          inferred_install_platform
        end

        def validate_install_artifacts(client_dir, platform:, device_id:)
          return true unless platform == "ios"

          return validate_ios_simulator_install_artifacts(client_dir) if ios_simulator_device_id?(device_id)

          device_app = File.join(client_dir, "build", "ios", "iphoneos", "Runner.app")
          return true unless Dir.exist?(device_app)
          return true if ios_app_signed?(device_app)

          warn "install config error: iOS device app bundle is not code signed"
          warn "Rebuild for a device with: ruflet build ios --self"
          warn "If you intentionally built without signing, install from Xcode or rebuild without --no-codesign."
          false
        end

        def validate_ios_simulator_install_artifacts(client_dir)
          simulator_app = File.join(client_dir, "build", "ios", "iphonesimulator", "Runner.app")
          return true if Dir.exist?(simulator_app)

          device_app = File.join(client_dir, "build", "ios", "iphoneos", "Runner.app")
          if Dir.exist?(device_app)
            warn "install config error: selected device is an iOS simulator, but the latest build is for iphoneos"
            warn "Rebuild for the simulator with: ruflet build ios --self --simulator"
          else
            warn "install config error: no iOS simulator app bundle was found"
            warn "Build the simulator target first with: ruflet build ios --self --simulator"
          end
          false
        end

        def ios_simulator_device_id?(device_id)
          return false if device_id.to_s.strip.empty?

          device_id.match?(/\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\z/i)
        end

        def ios_app_signed?(app_path)
          system("/usr/bin/codesign", "-vv", app_path, out: File::NULL, err: File::NULL)
        end

        def exports_for(platform)
          case platform
          when "apk", "android", "aab", "appbundle"
            { File.join("app", "outputs") => "android" }
          when "ios"
            { "ios" => "ios" }
          when "macos"
            { "macos" => "macos" }
          when "windows"
            { "windows" => "windows" }
          when "linux"
            { "linux" => "linux" }
          when "web"
            { "web" => "web" }
          else
            {}
          end
        end
      end
    end
  end
end
