# frozen_string_literal: true

require_relative "test_helper"

class MediaExtensionsCurrentFletTest < Minitest::Test
  def test_lottie_and_rive_support_the_current_flet_properties
    lottie = Ruflet.lottie(
      "loading.json",
      enable_layers_opacity: true,
      headers: { "Authorization" => "token" },
      error_content: Ruflet.text("Failed"),
      on_error: ->(_event) {}
    )
    rive = Ruflet.rive(
      "animation.riv",
      placeholder: Ruflet.progress_ring,
      use_artboard_size: true,
      speed_multiplier: 1.5,
      clip_rect: { left: 0, top: 0, right: 100, bottom: 100 }
    )

    assert_equal "Lottie", lottie.to_patch["_c"]
    assert_equal "Text", lottie.to_patch.dig("error_content", "_c")
    assert lottie.has_handler?(:error)
    assert_equal "Rive", rive.to_patch["_c"]
    assert_equal 1.5, rive.to_patch["speed_multiplier"]
  end

  def test_video_and_webview_accept_inherited_layout_and_current_extension_properties
    video = Ruflet.video(
      playlist: [{ resource: "movie.mp4" }],
      subtitle_track: { title: "English", language: "en", src: "captions.vtt" },
      margin: 8
    )
    webview = Ruflet.web_view(url: "https://flet.dev", margin: 12, col: { md: 6 })

    assert_equal({ "title" => "English", "language" => "en", "src" => "captions.vtt" }, video.to_patch["subtitle_track"])
    assert_equal 8, video.to_patch["margin"]
    assert_equal 12, webview.to_patch["margin"]
    assert_equal({ "md" => 6 }, webview.to_patch["col"])
  end
end
