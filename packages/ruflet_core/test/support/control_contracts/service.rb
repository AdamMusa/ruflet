# frozen_string_literal: true

require_relative "../control_contract"

# Contract specs for the services (lib/ruflet_ui/ruflet/ui/services).
# See test/support/control_contract.rb for the options and what they assert.

module ControlContract
  define(
    "service",
    {
      "accelerometer" => { wire: "Accelerometer" },
      "audio_recorder" => { wire: "AudioRecorder", aliases: %w[audiorecorder] },
      "barometer" => { wire: "Barometer" },
      "battery" => { wire: "Battery" },
      "browser_context_menu" => { wire: "BrowserContextMenu", aliases: %w[browsercontextmenu] },
      "camera" => { wire: "Camera" },
      "clipboard" => { wire: "Clipboard" },
      "connectivity" => { wire: "Connectivity" },
      "file_picker" => { wire: "FilePicker", aliases: %w[filepicker] },
      "flashlight" => { wire: "Flashlight" },
      "geolocator" => { wire: "Geolocator" },
      "gyroscope" => { wire: "Gyroscope" },
      "haptic_feedback" => { wire: "HapticFeedback", aliases: %w[hapticfeedback] },
      "local_authentication" => { wire: "LocalAuthentication", aliases: %w[localauthentication] },
      "magnetometer" => { wire: "Magnetometer" },
      "permission_handler" => { wire: "PermissionHandler", aliases: %w[permissionhandler] },
      "screen_brightness" => { wire: "ScreenBrightness", aliases: %w[screenbrightness] },
      "secure_storage" => { wire: "SecureStorage", aliases: %w[securestorage] },
      "semantics_service" => { wire: "SemanticsService", aliases: %w[semanticsservice] },
      "shake_detector" => { wire: "ShakeDetector", aliases: %w[shakedetector] },
      "share" => { wire: "Share" },
      "shared_preferences" => { wire: "SharedPreferences", aliases: %w[sharedpreferences] },
      "storage_paths" => { wire: "StoragePaths", aliases: %w[storagepaths] },
      "url_launcher" => { wire: "UrlLauncher", aliases: %w[urllauncher] },
      "user_accelerometer" => { wire: "UserAccelerometer", aliases: %w[useraccelerometer] },
      "wakelock" => { wire: "Wakelock" }
    }
  )
end
