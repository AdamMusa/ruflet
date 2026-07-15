# frozen_string_literal: true

require_relative "test_helper"

class RufletDividerCompatibilityTest < Minitest::Test
  def test_divider_serializes_current_flet_props
    divider = Ruflet.divider(
      color: "#ABCDEF",
      height: 12,
      leading_indent: 4,
      radius: 2,
      thickness: 1,
      trailing_indent: 6
    )

    patch = divider.to_patch

    assert_equal "Divider", patch["_c"]
    assert_equal "#abcdef", patch["color"]
    assert_equal 12, patch["height"]
    assert_equal 4, patch["leading_indent"]
    assert_equal 2, patch["radius"]
    assert_equal 1, patch["thickness"]
    assert_equal 6, patch["trailing_indent"]
  end

  def test_vertical_divider_serializes_current_flet_props_and_alias
    divider = Ruflet.vertical_divider(
      color: "#ABCDEF",
      leading_indent: 4,
      radius: { all: 2 },
      thickness: 1,
      trailing_indent: 6,
      width: 12
    )

    patch = divider.to_patch

    assert_equal "VerticalDivider", patch["_c"]
    assert_equal "VerticalDivider", Ruflet.verticaldivider(width: 1).to_patch["_c"]
    assert_equal "#abcdef", patch["color"]
    assert_equal 4, patch["leading_indent"]
    assert_equal({ "all" => 2 }, patch["radius"])
    assert_equal 1, patch["thickness"]
    assert_equal 6, patch["trailing_indent"]
    assert_equal 12, patch["width"]
  end

  def test_divider_serializes_negative_numeric_values_like_flet
    patch = Ruflet.divider(height: -1, leading_indent: -2, thickness: -3, trailing_indent: -4).to_patch

    assert_equal(-1, patch["height"])
    assert_equal(-2, patch["leading_indent"])
    assert_equal(-3, patch["thickness"])
    assert_equal(-4, patch["trailing_indent"])
  end

  def test_vertical_divider_serializes_negative_numeric_values_like_flet
    patch = Ruflet.vertical_divider(leading_indent: -1, thickness: -2, trailing_indent: -3, width: -4).to_patch

    assert_equal(-1, patch["leading_indent"])
    assert_equal(-2, patch["thickness"])
    assert_equal(-3, patch["trailing_indent"])
    assert_equal(-4, patch["width"])
  end
end
