# frozen_string_literal: true

require_relative "test_helper"

class RufletAudioCompatibilityTest < Minitest::Test
  def test_audio_serializes_flet_props_and_events
    audio = Ruflet.audio(
      src: "assets/intro.mp3",
      src_base64: "UklGRg==",
      autoplay: true,
      balance: -0.5,
      playback_rate: 1.25,
      release_mode: "loop",
      volume: 0.8,
      on_duration_change: ->(_event) {},
      on_loaded: ->(_event) {},
      on_position_change: ->(_event) {},
      on_seek_complete: ->(_event) {},
      on_state_change: ->(_event) {}
    )

    patch = audio.to_patch

    assert_equal "Audio", patch["_c"]
    assert_equal "assets/intro.mp3", patch["src"]
    assert_equal "UklGRg==", patch["src_base64"]
    assert_equal true, patch["autoplay"]
    assert_equal(-0.5, patch["balance"])
    assert_equal 1.25, patch["playback_rate"]
    assert_equal "loop", patch["release_mode"]
    assert_equal 0.8, patch["volume"]
    assert_equal true, patch["on_duration_change"]
    assert_equal true, patch["on_loaded"]
    assert_equal true, patch["on_position_change"]
    assert_equal true, patch["on_seek_complete"]
    assert_equal true, patch["on_state_change"]
    assert audio.has_handler?(:duration_change)
    assert audio.has_handler?(:loaded)
    assert audio.has_handler?(:position_change)
    assert audio.has_handler?(:seek_complete)
    assert audio.has_handler?(:state_change)
  end

  def test_page_audio_helper_and_release_method_use_flet_payload_shape
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    audio = page.audio(src: "assets/intro.mp3")
    messages.clear

    audio.release

    invoke_payload = messages.reverse.map(&:last).find { |payload| payload["name"] == "release" }
    refute_nil invoke_payload
    assert_equal audio.wire_id, invoke_payload["control_id"]
    assert_nil invoke_payload["args"]
  end
end
