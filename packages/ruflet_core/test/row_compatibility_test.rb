# frozen_string_literal: true

require_relative "test_helper"

class RufletRowCompatibilityTest < Minitest::Test
  def test_row_accepts_controls_as_first_argument_like_flet
    first = Ruflet.text("one")
    second = Ruflet.text("two")

    row = Ruflet.row(
      [first, second],
      alignment: "center",
      vertical_alignment: "end",
      spacing: 7,
      tight: true,
      wrap: true,
      run_spacing: 3,
      run_alignment: "space_between",
      intrinsic_height: true
    )

    patch = row.to_patch

    assert_equal "Row", patch["_c"]
    assert_equal [first, second], row.children
    refute row.props.key?("controls")
    assert_equal "center", patch["alignment"]
    assert_equal "end", patch["vertical_alignment"]
    assert_equal 7, patch["spacing"]
    assert_equal true, patch["tight"]
    assert_equal true, patch["wrap"]
    assert_equal 3, patch["run_spacing"]
    assert_equal "space_between", patch["run_alignment"]
    assert_equal true, patch["intrinsic_height"]
    assert_equal ["Text", "Text"], patch["controls"].map { |control| control["_c"] }
    assert_equal ["one", "two"], patch["controls"].map { |control| control["value"] }
  end
end
