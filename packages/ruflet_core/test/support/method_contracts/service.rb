# frozen_string_literal: true

require_relative "../method_contract"

# What each service method sends the client. See test/support/method_contract.rb.

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
      "initialize_camera" => { args: ["sample:description", "sample:resolution_preset"], name: "initialize", sends: {"description" => "sample:description", "resolution_preset" => "sample:resolution_preset", "enable_audio" => true} },
      "lock_capture_orientation" => { sends: {"orientation" => nil} },
      "pause_preview" => {  },
      "pause_video_recording" => {  },
      "prepare_for_video_recording" => {  },
      "resume_preview" => {  },
      "resume_video_recording" => {  },
      "set_description" => { args: ["sample:value"], sends: {"description" => "sample:value"} },
      "set_exposure_mode" => { args: ["sample:value"], sends: {"mode" => "sample:value"} },
      "set_exposure_offset" => { args: ["sample:value"], sends: {"offset" => "sample:value"} },
      "set_exposure_point" => { args: ["sample:value"], sends: {"point" => "sample:value"} },
      "set_flash_mode" => { args: ["sample:value"], sends: {"mode" => "sample:value"} },
      "set_focus_mode" => { args: ["sample:value"], sends: {"mode" => "sample:value"} },
      "set_focus_point" => { args: ["sample:value"], sends: {"point" => "sample:value"} },
      "set_zoom_level" => { args: ["sample:value"], sends: {"zoom" => "sample:value"} },
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
      "set" => { args: ["sample:value"], sends: {"data" => "sample:value"} },
      "set_files" => { args: ["sample:files"], sends: {"files" => ["sample:files"]} },
      "set_image" => { args: ["sample:value"], sends: {"data" => "sample:value"} }
    },
    "connectivity" => {
      "get_connectivity" => {  }
    },
    "file_picker" => {
      "get_directory_path" => { sends: {} },
      "pick_files" => { sends: {"file_type" => "any", "allow_multiple" => false, "with_data" => false} },
      "save_file" => { sends: {"file_type" => "any"} },
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
      "authenticate" => { kwargs: { localized_reason: "sample:localized_reason" }, sends: {"localized_reason" => "sample:localized_reason", "biometric_only" => false, "sensitive_transaction" => true, "persist_across_backgrounding" => false} },
      "authenticate_sync" => { kwargs: { localized_reason: "sample:localized_reason" }, sends: {"localized_reason" => "sample:localized_reason", "biometric_only" => false, "sensitive_transaction" => true, "persist_across_backgrounding" => false}, sync: true },
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
      "clear" => { sends: {} },
      "contains_key" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "get" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "get_all" => { sends: {} },
      "get_availability" => {  },
      "remove" => { args: ["sample:key"], sends: {"key" => "sample:key"} },
      "set" => { args: ["sample:key", "sample:value"], sends: {"key" => "sample:key", "value" => "sample:value"} }
    },
    "semantics_service" => {
      "announce_message" => { args: ["sample:message"], sends: {"message" => "sample:message", "rtl" => false, "assertiveness" => "polite"} },
      "announce_tooltip" => { args: ["sample:message"], sends: {"message" => "sample:message"} },
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
      "can_launch_url" => { args: ["sample:url"], sends: {"url" => "sample:url"} },
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
