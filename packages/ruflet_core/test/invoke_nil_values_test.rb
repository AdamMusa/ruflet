# frozen_string_literal: true

require_relative "test_helper"

# The args helpers behind service and map methods converted values with to_h
# when they could, and nil.to_h is {}. So an unset argument, or a nil inside
# an Array, reached the client as an empty map: camera.lock_capture_orientation()
# sent { "orientation" => {} }, which the renderer reads as a String? and
# fails on. nil must stay nil.
class InvokeNilValuesTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_camera_lock_capture_orientation_without_an_orientation_sends_nil
    camera = mount(Ruflet::UI::ControlFactory.build("camera"))

    camera.lock_capture_orientation

    assert_equal({ "orientation" => nil }, last_args)
  end

  def test_geolocator_keeps_nil_inside_its_settings
    @page.geolocator.get_current_position(configuration: { "accuracy" => "high", "steps" => [1, nil] })

    assert_equal({ "settings" => { "accuracy" => "high", "steps" => [1, nil] } }, last_args)
  end

  # Only the platform options (web, ios, macos, android, windows) go
  # through the conversion; the value is sent as given.
  def test_secure_storage_keeps_nil_inside_its_platform_options
    @page.secure_storage.set("k", [1, nil], android: { "reset_on_error" => true, "keys" => [nil] }, ios: [nil])

    assert_equal(
      { "key" => "k", "value" => [1, nil], "android" => { "reset_on_error" => true, "keys" => [nil] }, "ios" => [nil] },
      last_args
    )
  end

  def test_audio_recorder_keeps_nil_inside_its_configuration
    @page.audio_recorder.start_recording(configuration: { "channels" => [nil] })

    assert_equal({ "configuration" => { "channels" => [nil] } }, last_args)
  end

  def test_current_service_methods_keep_nil_inside_a_value
    prefs = Ruflet::UI::ControlFactory.build("shared_preferences")
    @page.add_service(prefs)

    prefs.set("k", [1, nil])

    assert_equal({ "key" => "k", "value" => [1, nil] }, last_args)
  end

  def test_map_methods_keep_nil_inside_an_option
    map = mount(Ruflet.map([]))

    map.zoom_in(offset: [1, nil])

    assert_equal({ "offset" => [1, nil] }, last_args)
  end

  private

  def mount(control)
    @page.add(control)
    control
  end

  def last_args
    @sent.reverse.find { |action, _| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }[1]["args"]
  end
end
