# frozen_string_literal: true

require_relative "test_helper"

class RufletPlaceholderCompatibilityTest < Minitest::Test
  def test_placeholder_accepts_positional_content_and_serializes_current_flet_props
    placeholder = Ruflet.placeholder(
      Ruflet.text("Soon"),
      color: "#336699",
      fallback_height: 240.0,
      fallback_width: 320.0,
      stroke_width: 3.5,
      expand: true
    )

    patch = placeholder.to_patch

    assert_equal "Placeholder", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "#336699", patch["color"]
    assert_equal 240.0, patch["fallback_height"]
    assert_equal 320.0, patch["fallback_width"]
    assert_equal 3.5, patch["stroke_width"]
    assert_equal true, patch["expand"]
  end

  def test_placeholder_defaults_match_flet
    placeholder = Ruflet.placeholder

    assert_nil placeholder.props["content"]
    assert_equal 400.0, placeholder.props["fallback_height"]
    assert_equal 400.0, placeholder.props["fallback_width"]
    assert_equal 2.0, placeholder.props["stroke_width"]
  end

  def test_placeholder_serializes_negative_numeric_dimensions_like_flet
    patch = Ruflet.placeholder(fallback_height: -1, fallback_width: -2, stroke_width: -3).to_patch

    assert_equal(-1, patch["fallback_height"])
    assert_equal(-2, patch["fallback_width"])
    assert_equal(-3, patch["stroke_width"])
  end
end
