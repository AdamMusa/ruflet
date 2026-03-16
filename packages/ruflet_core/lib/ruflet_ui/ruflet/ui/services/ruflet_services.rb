# frozen_string_literal: true

require_relative "ruflet/accelerometer_control"
require_relative "ruflet/barometer_control"
require_relative "ruflet/battery_control"
require_relative "ruflet/camera_control"
require_relative "ruflet/clipboard_control"
require_relative "ruflet/connectivity_control"
require_relative "ruflet/filepicker_control"
require_relative "ruflet/flashlight_control"
require_relative "ruflet/gyroscope_control"
require_relative "ruflet/hapticfeedback_control"
require_relative "ruflet/magnetometer_control"
require_relative "ruflet/screenbrightness_control"
require_relative "ruflet/screenshot_control"
require_relative "ruflet/semanticsservice_control"
require_relative "ruflet/shakedetector_control"
require_relative "ruflet/share_control"
require_relative "ruflet/sharedpreferences_control"
require_relative "ruflet/storagepaths_control"
require_relative "ruflet/urllauncher_control"
require_relative "ruflet/useraccelerometer_control"
require_relative "ruflet/wakelock_control"

module Ruflet
  module UI
    module Services
      module RufletServices
        module_function

        CLASS_MAP = {
          "accelerometer" => RufletServicesComponents::AccelerometerControl,
          "barometer" => RufletServicesComponents::BarometerControl,
          "battery" => RufletServicesComponents::BatteryControl,
          "camera" => RufletServicesComponents::CameraControl,
          "clipboard" => RufletServicesComponents::ClipboardControl,
          "connectivity" => RufletServicesComponents::ConnectivityControl,
          "file_picker" => RufletServicesComponents::FilePickerControl,
          "filepicker" => RufletServicesComponents::FilePickerControl,
          "flashlight" => RufletServicesComponents::FlashlightControl,
          "gyroscope" => RufletServicesComponents::GyroscopeControl,
          "haptic_feedback" => RufletServicesComponents::HapticFeedbackControl,
          "hapticfeedback" => RufletServicesComponents::HapticFeedbackControl,
          "magnetometer" => RufletServicesComponents::MagnetometerControl,
          "screen_brightness" => RufletServicesComponents::ScreenBrightnessControl,
          "screenbrightness" => RufletServicesComponents::ScreenBrightnessControl,
          "screenshot" => RufletServicesComponents::ScreenshotControl,
          "semantics_service" => RufletServicesComponents::SemanticsServiceControl,
          "semanticsservice" => RufletServicesComponents::SemanticsServiceControl,
          "shake_detector" => RufletServicesComponents::ShakeDetectorControl,
          "shakedetector" => RufletServicesComponents::ShakeDetectorControl,
          "share" => RufletServicesComponents::ShareControl,
          "shared_preferences" => RufletServicesComponents::SharedPreferencesControl,
          "sharedpreferences" => RufletServicesComponents::SharedPreferencesControl,
          "storage_paths" => RufletServicesComponents::StoragePathsControl,
          "storagepaths" => RufletServicesComponents::StoragePathsControl,
          "url_launcher" => RufletServicesComponents::UrlLauncherControl,
          "urllauncher" => RufletServicesComponents::UrlLauncherControl,
          "user_accelerometer" => RufletServicesComponents::UserAccelerometerControl,
          "useraccelerometer" => RufletServicesComponents::UserAccelerometerControl,
          "wakelock" => RufletServicesComponents::WakelockControl,
        }.freeze
      end
    end
  end
end
