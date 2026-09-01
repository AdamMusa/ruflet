# frozen_string_literal: true

require_relative "test_helper"

class ServiceDslHelperCoverageTest < Minitest::Test
  SERVICE_HELPERS = %i[
    accelerometer audio audio_recorder barometer battery browser_context_menu
    clipboard connectivity file_picker flashlight geolocator gyroscope
    haptic_feedback magnetometer permission_handler screen_brightness
    secure_storage semantics_service shake_detector share shared_preferences
    storage_paths url_launcher user_accelerometer wakelock
  ].freeze

  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def test_every_current_flet_service_has_a_direct_ruby_dsl_helper
    SERVICE_HELPERS.each { |helper| assert_respond_to Ruflet::DSL, helper }
  end

  def test_service_helpers_mount_services_in_the_app_registry
    clipboard = Ruflet::DSL.clipboard
    battery = Ruflet::DSL.battery
    app = Ruflet.app

    services = app.instance_variable_get(:@services)
    assert_includes services, clipboard
    assert_includes services, battery
  end

  def test_camera_remains_a_visual_in_process_control
    camera = Ruflet::DSL.camera(preview_enabled: true)
    app = Ruflet.app

    assert_includes app.instance_variable_get(:@roots), camera
    refute_includes app.instance_variable_get(:@services), camera
  end
end
