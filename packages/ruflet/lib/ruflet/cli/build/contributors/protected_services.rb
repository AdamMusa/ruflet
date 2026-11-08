# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Turns the declared services (camera, microphone, location, ...) into
        # Android permissions, Apple usage descriptions and macOS entitlements.
        module ProtectedServices
          PROTECTED_SERVICE_EXTENSIONS = {
            "biometrics" => %w[local_auth],
            "camera" => %w[camera permission_handler],
            "microphone" => %w[audio_recorder permission_handler],
            "location" => %w[geolocator permission_handler],
            "motion" => %w[permission_handler]
          }.freeze
          EXTENSION_REQUIRED_SERVICES = {
            "audio_recorder" => %w[microphone],
            "camera" => %w[camera],
            "flashlight" => %w[camera],
            "geolocator" => %w[location],
            "local_auth" => %w[biometrics],
            "qrcode_scanner" => %w[camera]
          }.freeze
          ANDROID_SERVICE_PERMISSIONS = {
            "camera" => %w[android.permission.CAMERA],
            "microphone" => %w[android.permission.RECORD_AUDIO],
            "location" => %w[android.permission.ACCESS_COARSE_LOCATION android.permission.ACCESS_FINE_LOCATION],
            "motion" => %w[android.permission.ACTIVITY_RECOGNITION android.permission.HIGH_SAMPLING_RATE_SENSORS]
          }.freeze
          IOS_SERVICE_USAGE_KEYS = {
            "biometrics" => "NSFaceIDUsageDescription",
            "camera" => "NSCameraUsageDescription",
            "microphone" => "NSMicrophoneUsageDescription",
            "location" => %w[
              NSLocationWhenInUseUsageDescription
              NSLocationAlwaysAndWhenInUseUsageDescription
            ],
            "motion" => "NSMotionUsageDescription",
            "photo_library" => "NSPhotoLibraryUsageDescription"
          }.freeze
          MACOS_SERVICE_USAGE_KEYS = {
            "camera" => "NSCameraUsageDescription",
            "microphone" => "NSMicrophoneUsageDescription",
            "location" => "NSLocationUsageDescription",
            "motion" => "NSMotionUsageDescription"
          }.freeze
          MACOS_SERVICE_ENTITLEMENTS = {
            "camera" => "com.apple.security.device.camera",
            "microphone" => "com.apple.security.device.audio-input",
            "location" => "com.apple.security.personal-information.location"
          }.freeze
          MANAGED_ANDROID_PERMISSIONS = (
            ANDROID_SERVICE_PERMISSIONS.values.flatten +
            %w[android.permission.FLASHLIGHT android.permission.MODIFY_AUDIO_SETTINGS]
          ).uniq.freeze
          MANAGED_IOS_USAGE_KEYS = (
            IOS_SERVICE_USAGE_KEYS.values.flatten +
            %w[NSLocationAlwaysAndWhenInUseUsageDescription NSPhotoLibraryUsageDescription]
          ).uniq.freeze
          MANAGED_MACOS_USAGE_KEYS = MACOS_SERVICE_USAGE_KEYS.values.uniq.freeze
          MANAGED_MACOS_SERVICE_ENTITLEMENTS = MACOS_SERVICE_ENTITLEMENTS.values.uniq.freeze

          private

          def contribute_protected_services(build)
            apply_native_service_permissions(build.client_dir, build.config)
            true
          end

          def configured_service_entries(config)
            Array(config["services"]).filter_map do |entry|
              case entry
              when Hash
                name, options = entry.first
                key = normalize_extension_key(name)
                next unless key

                description = options.is_a?(Hash) ? options["description"] || options[:description] : options
                { name: key, description: description.to_s.strip }
              else
                key = normalize_extension_key(entry)
                { name: key, description: "" } if key
              end
            end
          end

          def configured_service_entries_with_requirements(config)
            entries = configured_service_entries(config)
            configured_extensions = Array(config["extensions"]).filter_map do |entry|
              normalize_extension_key(entry) unless entry.is_a?(Hash)
            end
            configured_extensions.flat_map do |extension|
              EXTENSION_REQUIRED_SERVICES.fetch(extension, [])
            end.each do |service|
              entries << { name: service, description: "" } unless entries.any? { |entry| entry[:name] == service }
            end
            entries
          end

          def configured_extension_keys(config)
            services = configured_service_entries(config).map { |entry| entry[:name] }
            requested_extensions = Array(config["extensions"]).filter_map do |value|
              normalize_extension_key(value) unless value.is_a?(Hash)
            end
            protected_extensions = services.flat_map { |name| PROTECTED_SERVICE_EXTENSIONS.fetch(name, []) }
            (requested_extensions + protected_extensions + services).uniq
          end

          def apply_native_service_permissions(client_dir, config)
            entries = configured_service_entries_with_requirements(config)
            apply_android_service_permissions(client_dir, entries)
            apply_ios_service_usage_descriptions(client_dir, entries)
            apply_macos_service_permissions(client_dir, entries)
          end

          def apply_android_service_permissions(client_dir, entries)
            write_android_manifest_permissions(
              client_dir,
              managed: MANAGED_ANDROID_PERMISSIONS,
              permissions: entries.flat_map { |entry| ANDROID_SERVICE_PERMISSIONS.fetch(entry[:name], []) }.uniq
            )
          end

          def apply_ios_service_usage_descriptions(client_dir, entries)
            path = File.join(client_dir, "ios", "Runner", "Info.plist")
            apply_apple_service_usage_descriptions(
              path, entries, IOS_SERVICE_USAGE_KEYS, MANAGED_IOS_USAGE_KEYS)
          end

          def apply_macos_service_permissions(client_dir, entries)
            plist = File.join(client_dir, "macos", "Runner", "Info.plist")
            apply_apple_service_usage_descriptions(
              plist, entries, MACOS_SERVICE_USAGE_KEYS, MANAGED_MACOS_USAGE_KEYS)
            write_macos_entitlements(
              client_dir,
              managed: MANAGED_MACOS_SERVICE_ENTITLEMENTS,
              enabled: entries.filter_map { |entry| MACOS_SERVICE_ENTITLEMENTS[entry[:name]] }.uniq
            )
          end
        end

        register :protected_services, :contribute_protected_services
      end
    end
  end
end
