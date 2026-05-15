# frozen_string_literal: true

require_relative "test_helper"

class RufletColumnCompatibilityTest < Minitest::Test
  def test_column_accepts_children_as_first_argument_without_replacing_children_keyword
    first = Ruflet.text("one")
    second = Ruflet.text("two")

    column = Ruflet.column(
      [first, second],
      alignment: "center",
      horizontal_alignment: "end",
      spacing: 8,
      tight: true,
      wrap: true,
      run_spacing: 4,
      run_alignment: "space_around",
      intrinsic_width: true
    )

    patch = column.to_patch

    assert_equal "Column", patch["_c"]
    assert_equal [first, second], column.children
    refute column.props.key?("controls")
    assert_equal "center", patch["alignment"]
    assert_equal "end", patch["horizontal_alignment"]
    assert_equal 8, patch["spacing"]
    assert_equal true, patch["tight"]
    assert_equal true, patch["wrap"]
    assert_equal 4, patch["run_spacing"]
    assert_equal "space_around", patch["run_alignment"]
    assert_equal true, patch["intrinsic_width"]
    assert_equal ["Text", "Text"], patch["controls"].map { |control| control["_c"] }
    assert_equal ["one", "two"], patch["controls"].map { |control| control["value"] }
  end

  def test_column_keeps_ruflet_children_keyword
    first = Ruflet.text("first")
    second = Ruflet.text("second")

    column = Ruflet.column(children: [first, second])

    assert_equal [first, second], column.children
    refute column.props.key?("controls")
  end
end
