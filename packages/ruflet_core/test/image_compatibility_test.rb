# frozen_string_literal: true

require_relative "test_helper"

class RufletImageCompatibilityTest < Minitest::Test
  def test_image_serializes_current_flet_props_with_snake_case_keys
    error_content = Ruflet.text("missing")

    image = Ruflet.image(
      "https://example.com/image.png",
      error_content: error_content,
      repeat: "no_repeat",
      fit: "contain",
      border_radius: 8,
      color: "#ABCDEF",
      color_blend_mode: "src_in",
      gapless_playback: true,
      semantics_label: "Logo",
      exclude_from_semantics: true,
      filter_quality: "high",
      placeholder_src: "https://example.com/placeholder.png",
      placeholder_fit: "cover",
      fade_in_animation: 300,
      placeholder_fade_out_animation: 150,
      cache_width: 200,
      cache_height: 100,
      anti_alias: true
    )

    patch = image.to_patch

    assert_equal "Image", patch["_c"]
    assert_equal "https://example.com/image.png", patch["src"]
    assert_equal "Text", patch["error_content"]["_c"]
    assert_equal "missing", patch["error_content"]["value"]
    assert_equal "no_repeat", patch["repeat"]
    assert_equal "contain", patch["fit"]
    assert_equal 8, patch["border_radius"]
    assert_equal "#abcdef", patch["color"]
    assert_equal "src_in", patch["color_blend_mode"]
    assert_equal true, patch["gapless_playback"]
    assert_equal "Logo", patch["semantics_label"]
    assert_equal true, patch["exclude_from_semantics"]
    assert_equal "high", patch["filter_quality"]
    assert_equal "https://example.com/placeholder.png", patch["placeholder_src"]
    assert_equal "cover", patch["placeholder_fit"]
    assert_equal 300, patch["fade_in_animation"]
    assert_equal 150, patch["placeholder_fade_out_animation"]
    assert_equal 200, patch["cache_width"]
    assert_equal 100, patch["cache_height"]
    assert_equal true, patch["anti_alias"]
  end

  def test_image_keeps_src_base64_separate_from_src
    image = Ruflet.image(src_base64: "aGVsbG8=")

    patch = image.to_patch

    assert_equal "Image", patch["_c"]
    assert_equal "aGVsbG8=", patch["src_base64"]
    refute patch.key?("src")
  end
end
