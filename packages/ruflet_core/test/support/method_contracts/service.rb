# frozen_string_literal: true

require "pathname"
require "uri"
require_relative "../method_contract"

# What each service method sends the client. See test/support/method_contract.rb.
# A method that converts an argument (to_s, a Symbol name, packed bytes)
# gets a value the conversion changes, so the spec fails without it.

MethodContract.define(
  {
    "audio_recorder" => {
      "cancel_recording" => {  },
      "get_input_devices" => {  },
      "has_permission" => {  },
      "is_paused" => {  },
      "is_recording" => {  },
      "is_supported_encoder" => { args: ["sample:encoder"], sends: {"encoder" => "sample:encoder"} },
      "pause_recording" => {  },
      "resume_recording" => {  },
      "start_recording" => { sends: {"configuration" => {}} },
      "stop_recording" => {  }
    },
    "battery" => {
      "get_battery_level" => {  },
      "get_battery_state" => {  },
      "is_in_battery_save_mode" => {  }
    },
    "browser_context_menu" => {
      "disable" => { name: "disable_menu" },
      "disabled" => { local: "reads the state the last enable/disable set (page_browser_context_menu_service_test)" },
      "disabled?" => { local: "reads the state the last enable/disable set (page_browser_context_menu_service_test)" },
      "enable" => { name: "enable_menu" }
    },
    "camera" => {
      "get_available_cameras" => {  },
      "get_exposure_offset_step_size" => {  },
      "get_max_exposure_offset" => {  },
      "get_max_zoom_level" => {  },
      "get_min_exposure_offset" => {  },
      "get_min_zoom_level" => {  },
      "initialize_camera" => { args: [{ name: "0", lens_direction: :back }, :high], name: "initialize", sends: {"description" => {"name" => "0", "lens_direction" => "back"}, "resolution_preset" => "high", "enable_audio" => true} },
      # Without an orientation it sends nil (invoke_nil_values_test).
      "lock_capture_orientation" => { args: [:portrait_up], sends: {"orientation" => "portrait_up"} },
      "pause_preview" => {  },
      "pause_video_recording" => {  },
      "prepare_for_video_recording" => {  },
      "resume_preview" => {  },
      "resume_video_recording" => {  },
      "set_description" => { args: [{ name: "1", lens_direction: :front }], sends: {"description" => {"name" => "1", "lens_direction" => "front"}} },
      "set_exposure_mode" => { args: [:auto], sends: {"mode" => "auto"} },
      "set_exposure_offset" => { args: [0.5], sends: {"offset" => 0.5} },
      "set_exposure_point" => { args: [{ x: 0.5, y: 0.25 }], sends: {"point" => {"x" => 0.5, "y" => 0.25}} },
      "set_flash_mode" => { args: [:torch], sends: {"mode" => "torch"} },
      "set_focus_mode" => { args: [:locked], sends: {"mode" => "locked"} },
      "set_focus_point" => { args: [[0.5, 0.25]], sends: {"point" => [0.5, 0.25]} },
      "set_zoom_level" => { args: [2.0], sends: {"zoom" => 2.0} },
      "start_image_stream" => {  },
      "start_video_recording" => {  },
      "stop_image_stream" => {  },
      "stop_video_recording" => {  },
      "supports_image_streaming" => {  },
      "take_picture" => {  },
      "unlock_capture_orientation" => {  }
    },
    "clipboard" => {
      "get" => {  },
      "get_files" => {  },
      "get_image" => {  },
      "set" => { args: [42], sends: {"data" => "42"} },
      "set_files" => { args: [Pathname("/tmp/a.txt")], sends: {"files" => ["/tmp/a.txt"]} },
      "set_image" => { args: ["sample:value"], sends: {"data" => "sample:value"} }
    },
    "connectivity" => {
      "get_connectivity" => {  }
    },
    "file_picker" => {
      "get_directory_path" => { sends: {} },
      "pick_files" => { sends: {"file_type" => "any", "allow_multiple" => false, "with_data" => false} },
      "save_file" => { kwargs: { file_name: :report, src_bytes: [1, 2, 255] }, sends: {"file_name" => "report", "file_type" => "any", "src_bytes" => "\x01\x02\xFF".b} },
      "upload" => { args: ["sample:files"], sends: {"files" => "sample:files"} }
    },
    # flashlight.on replaces Ruflet::Control#on: it turns the light on.
    "flashlight" => {
      "is_available" => {  },
      "off" => {  },
      "on" => {  }
    },
    "geolocator" => {
      "distance_between" => { args: ["sample:start_latitude", "sample:start_longitude", "sample:end_latitude", "sample:end_longitude"], sends: {"start_latitude" => "sample:start_latitude", "start_longitude" => "sample:start_longitude", "end_latitude" => "sample:end_latitude", "end_longitude" => "sample:end_longitude"} },
      "get_current_position" => {  },
      "get_last_known_position" => {  },
      "get_permission_status" => {  },
      "is_location_service_enabled" => {  },
      "open_app_settings" => {  },
      "open_location_settings" => {  },
      "request_permission" => {  }
    },
    "haptic_feedback" => {
      "heavy_impact" => {  },
      "light_impact" => {  },
      "medium_impact" => {  },
      "selection_click" => {  },
      "vibrate" => {  }
    },
    "local_authentication" => {
      "authenticate" => { kwargs: { localized_reason: :unlock, biometric_only: 1, android_messages: { sign_in_title: :title, cancel_button: nil } }, sends: {"localized_reason" => "unlock", "biometric_only" => true, "sensitive_transaction" => true, "persist_across_backgrounding" => false, "android_messages" => {"sign_in_title" => "title"}} },
      "authenticate_sync" => { kwargs: { localized_reason: :unlock, sensitive_transaction: nil, persist_across_backgrounding: "yes", ios_messages: { cancel_button: :cancel } }, sends: {"localized_reason" => "unlock", "biometric_only" => false, "sensitive_transaction" => false, "persist_across_backgrounding" => true, "ios_messages" => {"cancel_button" => "cancel"}}, sync: true },
      "can_check_biometrics" => {  },
      "can_check_biometrics_sync" => { sync: true },
      "device_supported?" => { name: "is_device_supported" },
      "get_available_biometrics" => {  },
      "get_available_biometrics_sync" => { sync: true },
      "is_device_supported" => {  },
      "is_device_supported_sync" => { sync: true },
      "stop_authentication" => {  },
      "stop_authentication_sync" => { sync: true }
    },
    "permission_handler" => {
      "get_status" => { args: ["sample:permission"], sends: {"permission" => "sample:permission"} },
      "open_app_settings" => {  },
      "request" => { args: ["sample:permission"], sends: {"permission" => "sample:permission"} }
    },
    "screen_brightness" => {
      "can_change_system_screen_brightness" => {  },
      "get_application_screen_brightness" => {  },
      "get_system_screen_brightness" => {  },
      "is_animate" => {  },
      "is_auto_reset" => {  },
      "reset_application_screen_brightness" => {  },
      "set_animate" => { args: ["sample:animate"], sends: {"animate" => "sample:animate"} },
      "set_application_screen_brightness" => { args: ["sample:brightness"], sends: {"brightness" => "sample:brightness"} },
      "set_auto_reset" => { args: ["sample:auto_reset"], sends: {"auto_reset" => "sample:auto_reset"} },
      "set_system_screen_brightness" => { args: ["sample:brightness"], sends: {"brightness" => "sample:brightness"} }
    },
    "secure_storage" => {
      # Each platform option key is sent; its value's keys become Strings.
      "clear" => { kwargs: { android: { reset_on_error: true } }, sends: {"android" => {"reset_on_error" => true}} },
      "contains_key" => { args: ["sample:key"], kwargs: { web: { db_name: "db" } }, sends: {"key" => "sample:key", "web" => {"db_name" => "db"}} },
      "get" => { args: ["sample:key"], kwargs: { ios: { accessibility: "first_unlock" } }, sends: {"key" => "sample:key", "ios" => {"accessibility" => "first_unlock"}} },
      "get_all" => { kwargs: { macos: { synchronizable: true } }, sends: {"macos" => {"synchronizable" => true}} },
      "get_availability" => {  },
      "remove" => { args: ["sample:key"], kwargs: { windows: { use_backward_compatibility: true } }, sends: {"key" => "sample:key", "windows" => {"use_backward_compatibility" => true}} },
      "set" => { args: ["sample:key", "sample:value"], sends: {"key" => "sample:key", "value" => "sample:value"} }
    },
    "semantics_service" => {
      "announce_message" => { args: [:saved], kwargs: { rtl: 1, assertiveness: :assertive }, sends: {"message" => "saved", "rtl" => true, "assertiveness" => "assertive"} },
      "announce_tooltip" => { args: [:saved], sends: {"message" => "saved"} },
      "get_accessibility_features" => {  }
    },
    "share" => {
      "share_files" => { args: ["sample:files"], sends: {"files" => "sample:files", "download_fallback_enabled" => true, "mail_to_fallback_enabled" => true} },
      "share_text" => { args: ["sample:text"], sends: {"text" => "sample:text", "download_fallback_enabled" => true, "mail_to_fallback_enabled" => true} },
      "share_uri" => { args: ["sample:uri"], sends: {"uri" => "sample:uri"} }
    },
    "shared_preferences" => {
      "clear" => {  },
      "contains_key" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "get" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "get_keys" => { args: ["sample:key_prefix"], sends: {"key_prefix" => "sample:key_prefix"} },
      "remove" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "set" => { args: ["sample:key", "sample:value"], sends: {"key" => "sample:key", "value" => "sample:value"} }
    },
    "storage_paths" => {
      "get_application_cache_directory" => {  },
      "get_application_documents_directory" => {  },
      "get_application_support_directory" => {  },
      "get_console_log_filename" => {  },
      "get_downloads_directory" => {  },
      "get_external_cache_directories" => {  },
      "get_external_storage_directories" => {  },
      "get_external_storage_directory" => {  },
      "get_library_directory" => {  },
      "get_temporary_directory" => {  }
    },
    "url_launcher" => {
      "can_launch_url" => { args: [URI("https://example.com/")], sends: {"url" => "https://example.com/"} },
      "close_in_app_web_view" => {  },
      "launch_url" => { args: ["sample:url"], sends: {"url" => "sample:url", "mode" => "platform_default"} },
      "open_window" => { args: ["sample:url"], sends: {"url" => "sample:url"} },
      "supports_close_for_launch_mode" => { args: ["sample:mode"], sends: {"mode" => "sample:mode"} },
      "supports_launch_mode" => { args: ["sample:mode"], sends: {"mode" => "sample:mode"} }
    },
    "wakelock" => {
      "disable" => {  },
      "enable" => {  },
      "is_enabled" => {  }
    }
  }
)
