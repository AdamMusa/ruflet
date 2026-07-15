# frozen_string_literal: true

require_relative "test_helper"

class PageExtensionServicesTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_audio_recorder_uses_typed_service_and_invocation_api
    recorder = @page.audio_recorder(on_state_change: ->(_event) {})

    assert_equal "AudioRecorder", recorder.to_patch["_c"]
    assert recorder.has_handler?(:state_change)

    @page.add(Ruflet.text("ready"))
    recorder.start_recording(output_path: "/tmp/test.wav", configuration: { encoder: :wav }, on_result: ->(*) {})

    invoke = @sent.last[1]
    assert_equal "start_recording", invoke["name"]
    assert_equal({ "output_path" => "/tmp/test.wav", "configuration" => { "encoder" => :wav } }, invoke["args"])
  end

  def test_audio_recorder_uses_its_default_configuration
    recorder = @page.audio_recorder
    recorder.start_recording(output_path: "/tmp/test.wav", on_result: ->(*) {})

    assert_equal({}, @sent.last[1].dig("args", "configuration"))
  end

  def test_geolocator_permission_handler_and_secure_storage_are_typed_services
    assert_equal "Geolocator", @page.geolocator.to_patch["_c"]
    assert_equal "PermissionHandler", @page.permission_handler.to_patch["_c"]
    assert_equal "SecureStorage", @page.secure_storage.to_patch["_c"]
  end

  def test_geolocator_configuration_uses_the_flutter_service_argument
    geolocator = @page.geolocator
    geolocator.get_current_position(configuration: { accuracy: :high }, on_result: ->(*) {})

    invoke = @sent.last[1]
    assert_equal "get_current_position", invoke["name"]
    assert_equal({ "settings" => { "accuracy" => :high } }, invoke["args"])
  end
end
