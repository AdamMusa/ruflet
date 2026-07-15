# frozen_string_literal: true

require_relative "test_helper"

class PageAudioRecorderServiceTest < Minitest::Test
  def test_audio_recorder_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.audio_recorder(configuration: { encoder: "aac_lc" }, on_state_change: ->(_event) {})

    assert_equal "audiorecorder", service.type
    assert_equal "AudioRecorder", service.to_patch["_c"]
    assert_equal({ "encoder" => "aac_lc" }, service.to_patch["configuration"])
    assert_equal true, service.props["on_state_change"]
    assert service.has_handler?(:state_change)
    assert_same service, page.service(:audio_recorder)
  end

  def test_audio_recorder_methods_use_flet_payload_shape
    sent = []
    page = build_page(sent)
    service = page.audio_recorder

    service.start_recording(output_path: "/tmp/a.wav", configuration: { encoder: "wav" }, upload: { url: "/upload" })
    service.start_recording(output_path: "/tmp/b.wav")
    service.is_supported_encoder("wav")
    service.stop_recording
    service.cancel_recording

    payloads = sent.map(&:last)
    assert_equal(
      {
        "output_path" => "/tmp/a.wav",
        "configuration" => { "encoder" => "wav" },
        "upload" => { "url" => "/upload" }
      },
      payloads.find { |payload| payload["name"] == "start_recording" }["args"]
    )
    assert_equal(
      {
        "output_path" => "/tmp/b.wav",
        "configuration" => {}
      },
      payloads.select { |payload| payload["name"] == "start_recording" }.last["args"]
    )
    assert_equal({ "encoder" => "wav" }, payloads.find { |payload| payload["name"] == "is_supported_encoder" }["args"])
    assert_nil payloads.find { |payload| payload["name"] == "stop_recording" }["args"]
    assert_nil payloads.find { |payload| payload["name"] == "cancel_recording" }["args"]
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
