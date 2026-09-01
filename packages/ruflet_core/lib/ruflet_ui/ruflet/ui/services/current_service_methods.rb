# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module CurrentServiceMethods
        private

        def invoke_service_method(method_name, args: nil, timeout: 10, on_result: nil)
          runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
        end

        def service_args(values)
          values.each_with_object({}) do |(key, value), result|
            result[key.to_s] = service_value(value, key.to_s) unless value.nil?
          end
        end

        def service_value(value, parent_key = nil)
          if parent_key == "data" && byte_array?(value)
            return value.pack("C*").b
          end

          case value
          when Array
            value.map { |item| service_value(item) }
          when Hash
            value.each_with_object({}) do |(key, item), result|
              result[key.to_s] = service_value(item, key.to_s) unless item.nil?
            end
          when Symbol
            value.to_s
          else
            value.respond_to?(:to_h) ? service_value(value.to_h) : value
          end
        end

        def byte_array?(value)
          value.is_a?(Array) && value.all? { |item| item.is_a?(Integer) && item.between?(0, 255) }
        end
      end

      module NoArgumentServiceMethods
        def define_no_argument_service_methods(*method_names)
          method_names.each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_service_method(method_name, timeout: timeout, on_result: on_result)
            end
          end
        end
      end

      components = RufletServicesComponents

      [
        [components::BatteryControl, %w[get_battery_level get_battery_state is_in_battery_save_mode]],
        [components::ConnectivityControl, %w[get_connectivity]],
        [components::FlashlightControl, %w[on off is_available]],
        [components::HapticFeedbackControl, %w[heavy_impact light_impact medium_impact vibrate selection_click]],
        [components::StoragePathsControl, %w[
          get_application_cache_directory get_application_documents_directory
          get_application_support_directory get_downloads_directory
          get_external_cache_directories get_external_storage_directories
          get_library_directory get_external_storage_directory
          get_temporary_directory get_console_log_filename
        ]],
        [components::WakelockControl, %w[enable disable is_enabled]]
      ].each do |klass, method_names|
        klass.include(CurrentServiceMethods)
        klass.extend(NoArgumentServiceMethods)
        klass.define_no_argument_service_methods(*method_names)
      end

      class RufletServicesComponents::FilePickerControl
        include CurrentServiceMethods

        def upload(files, timeout: 10, on_result: nil)
          invoke_service_method("upload", args: { "files" => service_value(files) }, timeout: timeout, on_result: on_result)
        end

        def get_directory_path(dialog_title: nil, initial_directory: nil, timeout: 10, on_result: nil)
          invoke_service_method("get_directory_path", args: service_args(dialog_title: dialog_title, initial_directory: initial_directory), timeout: timeout, on_result: on_result)
        end

        def save_file(dialog_title: nil, file_name: nil, initial_directory: nil, file_type: :any,
                      allowed_extensions: nil, src_bytes: nil, timeout: 10, on_result: nil)
          args = service_args(
            dialog_title: dialog_title,
            file_name: file_name,
            initial_directory: initial_directory,
            file_type: file_type,
            allowed_extensions: allowed_extensions
          )
          args["src_bytes"] = src_bytes.pack("C*").b if byte_array?(src_bytes)
          args["src_bytes"] = src_bytes unless src_bytes.nil? || byte_array?(src_bytes)
          invoke_service_method("save_file", args: args, timeout: timeout, on_result: on_result)
        end

        def pick_files(dialog_title: nil, initial_directory: nil, file_type: :any,
                       allowed_extensions: nil, allow_multiple: false, with_data: false,
                       timeout: 10, on_result: nil)
          invoke_service_method(
            "pick_files",
            args: service_args(
              dialog_title: dialog_title,
              initial_directory: initial_directory,
              file_type: file_type,
              allowed_extensions: allowed_extensions,
              allow_multiple: allow_multiple,
              with_data: with_data
            ),
            timeout: timeout,
            on_result: on_result
          )
        end
      end

      class RufletServicesComponents::ScreenBrightnessControl
        include CurrentServiceMethods

        %w[
          get_system_screen_brightness can_change_system_screen_brightness
          get_application_screen_brightness reset_application_screen_brightness
          is_animate is_auto_reset
        ].each do |method_name|
          define_method(method_name) do |timeout: 10, on_result: nil|
            invoke_service_method(method_name, timeout: timeout, on_result: on_result)
          end
        end

        def set_system_screen_brightness(brightness, timeout: 10, on_result: nil)
          invoke_service_method("set_system_screen_brightness", args: { "brightness" => brightness }, timeout: timeout, on_result: on_result)
        end

        def set_application_screen_brightness(brightness, timeout: 10, on_result: nil)
          invoke_service_method("set_application_screen_brightness", args: { "brightness" => brightness }, timeout: timeout, on_result: on_result)
        end

        def set_animate(animate, timeout: 10, on_result: nil)
          invoke_service_method("set_animate", args: { "animate" => animate }, timeout: timeout, on_result: on_result)
        end

        def set_auto_reset(auto_reset, timeout: 10, on_result: nil)
          invoke_service_method("set_auto_reset", args: { "auto_reset" => auto_reset }, timeout: timeout, on_result: on_result)
        end
      end

      class RufletServicesComponents::ShareControl
        include CurrentServiceMethods

        def share_text(text, title: nil, subject: nil, preview_thumbnail: nil,
                       share_position_origin: nil, download_fallback_enabled: true,
                       mail_to_fallback_enabled: true, excluded_cupertino_activities: nil,
                       timeout: 10, on_result: nil)
          invoke_service_method(
            "share_text",
            args: service_args(
              text: text, title: title, subject: subject, preview_thumbnail: preview_thumbnail,
              share_position_origin: share_position_origin,
              download_fallback_enabled: download_fallback_enabled,
              mail_to_fallback_enabled: mail_to_fallback_enabled,
              excluded_cupertino_activities: excluded_cupertino_activities
            ),
            timeout: timeout,
            on_result: on_result
          )
        end

        def share_uri(uri, share_position_origin: nil, excluded_cupertino_activities: nil, timeout: 10, on_result: nil)
          invoke_service_method("share_uri", args: service_args(uri: uri, share_position_origin: share_position_origin, excluded_cupertino_activities: excluded_cupertino_activities), timeout: timeout, on_result: on_result)
        end

        def share_files(files, title: nil, text: nil, subject: nil, preview_thumbnail: nil,
                        share_position_origin: nil, download_fallback_enabled: true,
                        mail_to_fallback_enabled: true, excluded_cupertino_activities: nil,
                        timeout: 10, on_result: nil)
          invoke_service_method(
            "share_files",
            args: service_args(
              files: files, title: title, text: text, subject: subject,
              preview_thumbnail: preview_thumbnail, share_position_origin: share_position_origin,
              download_fallback_enabled: download_fallback_enabled,
              mail_to_fallback_enabled: mail_to_fallback_enabled,
              excluded_cupertino_activities: excluded_cupertino_activities
            ),
            timeout: timeout,
            on_result: on_result
          )
        end
      end

      class RufletServicesComponents::SharedPreferencesControl
        include CurrentServiceMethods

        def set(key, value, timeout: 10, on_result: nil) = invoke_service_method("set", args: { "key" => key, "value" => service_value(value) }, timeout: timeout, on_result: on_result)
        def get(key, timeout: 10, on_result: nil) = invoke_service_method("get", args: { "key" => key }, timeout: timeout, on_result: on_result)
        def contains_key(key, timeout: 10, on_result: nil) = invoke_service_method("contains_key", args: { "key" => key }, timeout: timeout, on_result: on_result)
        def remove(key, timeout: 10, on_result: nil) = invoke_service_method("remove", args: { "key" => key }, timeout: timeout, on_result: on_result)
        def get_keys(key_prefix, timeout: 10, on_result: nil) = invoke_service_method("get_keys", args: { "key_prefix" => key_prefix }, timeout: timeout, on_result: on_result)
        def clear(timeout: 10, on_result: nil) = invoke_service_method("clear", timeout: timeout, on_result: on_result)
      end

      class RufletServicesComponents::UrlLauncherControl
        include CurrentServiceMethods

        def launch_url(url, mode: :platform_default, web_view_configuration: nil,
                       browser_configuration: nil, web_only_window_name: nil,
                       timeout: 10, on_result: nil)
          invoke_service_method("launch_url", args: service_args(url: url, mode: mode, web_view_configuration: web_view_configuration, browser_configuration: browser_configuration, web_only_window_name: web_only_window_name), timeout: timeout, on_result: on_result)
        end

        def can_launch_url(url, timeout: 10, on_result: nil) = invoke_service_method("can_launch_url", args: { "url" => url.to_s }, timeout: timeout, on_result: on_result)
        def close_in_app_web_view(timeout: 10, on_result: nil) = invoke_service_method("close_in_app_web_view", timeout: timeout, on_result: on_result)
        def open_window(url, title: nil, width: nil, height: nil, timeout: 10, on_result: nil) = invoke_service_method("open_window", args: service_args(url: url, title: title, width: width, height: height), timeout: timeout, on_result: on_result)
        def supports_launch_mode(mode, timeout: 10, on_result: nil) = invoke_service_method("supports_launch_mode", args: { "mode" => service_value(mode) }, timeout: timeout, on_result: on_result)
        def supports_close_for_launch_mode(mode, timeout: 10, on_result: nil) = invoke_service_method("supports_close_for_launch_mode", args: { "mode" => service_value(mode) }, timeout: timeout, on_result: on_result)
      end
    end
  end
end
