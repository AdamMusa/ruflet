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

  def test_divider_rejects_negative_numeric_values_like_flet
    %i[height leading_indent thickness trailing_indent].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.divider(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_vertical_divider_rejects_negative_numeric_values_like_flet
    %i[leading_indent thickness trailing_indent width].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.vertical_divider(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end
end
