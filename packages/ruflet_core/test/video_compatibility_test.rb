# frozen_string_literal: true

require_relative "test_helper"

class RufletVideoCompatibilityTest < Minitest::Test
  def test_video_serializes_flet_props_and_events
    video = Ruflet.video(
      playlist: [{ resource: "https://example.com/video.mp4" }],
      alignment: { x: 0, y: 0 },
      aspect_ratio: 16 / 9.0,
      autoplay: true,
      configuration: { width: 640, height: 360 },
      fill_color: "#000000",
      filter_quality: "high",
      fit: "contain",
      fullscreen: false,
      muted: true,
      pause_upon_entering_background_mode: true,
      pitch: 1.0,
      playback_rate: 1.25,
      playlist_mode: "loop",
      resume_upon_entering_foreground_mode: true,
      show_controls: true,
      shuffle_playlist: false,
      subtitle_configuration: { src: "captions.vtt" },
      title: "Demo video",
      volume: 80,
      wakelock: true,
      on_completed: ->(_event) {},
      on_enter_fullscreen: ->(_event) {},
      on_error: ->(_event) {},
      on_exit_fullscreen: ->(_event) {},
      on_loaded: ->(_event) {},
      on_track_changed: ->(_event) {}
    )

    patch = video.to_patch

    assert_equal "Video", patch["_c"]
    assert_equal [{ "resource" => "https://example.com/video.mp4" }], patch["playlist"]
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal 16 / 9.0, patch["aspect_ratio"]
    assert_equal true, patch["autoplay"]
    assert_equal({ "width" => 640, "height" => 360 }, patch["configuration"])
    assert_equal "#000000", patch["fill_color"]
    assert_equal "high", patch["filter_quality"]
    assert_equal "contain", patch["fit"]
    assert_equal false, patch["fullscreen"]
    assert_equal true, patch["muted"]
    assert_equal true, patch["pause_upon_entering_background_mode"]
    assert_equal 1.0, patch["pitch"]
    assert_equal 1.25, patch["playback_rate"]
    assert_equal "loop", patch["playlist_mode"]
    assert_equal true, patch["resume_upon_entering_foreground_mode"]
    assert_equal true, patch["show_controls"]
    assert_equal false, patch["shuffle_playlist"]
    assert_equal({ "src" => "captions.vtt" }, patch["subtitle_configuration"])
    assert_equal "Demo video", patch["title"]
    assert_equal 80, patch["volume"]
    assert_equal true, patch["wakelock"]
    assert_equal true, patch["on_completed"]
    assert_equal true, patch["on_enter_fullscreen"]
    assert_equal true, patch["on_error"]
    assert_equal true, patch["on_exit_fullscreen"]
    assert_equal true, patch["on_loaded"]
    assert_equal true, patch["on_track_changed"]
    assert video.has_handler?(:completed)
    assert video.has_handler?(:enter_fullscreen)
    assert video.has_handler?(:error)
    assert video.has_handler?(:exit_fullscreen)
    assert video.has_handler?(:loaded)
    assert video.has_handler?(:track_changed)
  end

  def test_video_methods_invoke_flet_control_methods
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    video = Ruflet.video(playlist: [{ resource: "https://example.com/video.mp4" }])
    page.add(video)
    messages.clear

    video.play
    video.pause
    video.play_or_pause
    video.stop
    video.next
    video.previous
    video.jump_to(1)
    video.seek(10_000)
    video.playlist_add(resource: "https://example.com/next.mp4")
    video.playlist_remove(0)
    video.get_current_position
    video.get_duration
    video.is_completed
    video.is_playing

    assert_equal %w[
      play pause play_or_pause stop next previous jump_to seek playlist_add playlist_remove
      get_current_position get_duration is_completed is_playing
    ], messages.map { |_action, payload| payload["name"] }
    assert_nil messages[0].last["args"]
    assert_equal({ "media_index" => 1 }, messages[6].last["args"])
    assert_equal({ "position" => 10_000 }, messages[7].last["args"])
    assert_equal({ "media" => { "resource" => "https://example.com/next.mp4" } }, messages[8].last["args"])
    assert_equal({ "media_index" => 0 }, messages[9].last["args"])
  end
end
