# frozen_string_literal: true

require_relative "test_helper"

class RufletRotatedBoxCompatibilityTest < Minitest::Test
  def test_rotated_box_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.rotated_box(
      Ruflet.text("Rotate me"),
      quarter_turns: 1,
      expand: true,
      width: 200,
      height: 100
    )

    patch = control.to_patch

    assert_equal "RotatedBox", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal 1, patch["quarter_turns"]
    assert_equal true, patch["expand"]
    assert_equal 200, patch["width"]
    assert_equal 100, patch["height"]
  end

  def test_compact_alias_uses_same_control
    control = Ruflet.rotatedbox(Ruflet.text("Alias"), quarter_turns: 2)

    assert_equal "rotatedbox", control.type
    assert_equal "RotatedBox", control.to_patch["_c"]
    assert_equal 2, control.to_patch["quarter_turns"]
  end

  def test_rotated_box_allows_nil_content_like_flet
    control = Ruflet.rotated_box

    assert_nil control.props["content"]
    assert_equal 0, control.props["quarter_turns"]
    assert_equal "RotatedBox", control.to_patch["_c"]
  end
end
