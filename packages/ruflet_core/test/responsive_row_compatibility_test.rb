# frozen_string_literal: true

require_relative "test_helper"

class RufletResponsiveRowCompatibilityTest < Minitest::Test
  def test_responsive_row_accepts_positional_children_and_serializes_current_flet_props
    first = Ruflet.button(content: "One", col: { xs: 12, md: 6 })
    second = Ruflet.button(content: "Two", col: 6)

    row = Ruflet.responsive_row(
      [first, second],
      alignment: "center",
      breakpoints: { phone: 0, tablet: 540 },
      columns: { phone: 4, tablet: 8 },
      run_spacing: { phone: 6, tablet: 8 },
      spacing: 4,
      vertical_alignment: "end"
    )

    patch = row.to_patch

    assert_equal "ResponsiveRow", patch["_c"]
    assert_equal [first, second], row.children
    refute row.props.key?("controls")
    assert_equal ["One", "Two"], patch["controls"].map { |control| control["content"] }
    assert_equal "center", patch["alignment"]
    assert_equal({ "phone" => 0, "tablet" => 540 }, patch["breakpoints"])
    assert_equal({ "phone" => 4, "tablet" => 8 }, patch["columns"])
    assert_equal({ "phone" => 6, "tablet" => 8 }, patch["run_spacing"])
    assert_equal 4, patch["spacing"]
    assert_equal "end", patch["vertical_alignment"]
  end

  def test_responsive_row_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.responsive_row(children: [first])
    with_controls_alias = Ruflet.responsive_row(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_alias_uses_same_control
    row = Ruflet.responsiverow([Ruflet.text("One")])

    assert_equal "responsiverow", row.type
    assert_equal "ResponsiveRow", row.to_patch["_c"]
  end

  def test_responsive_row_defaults_match_flet
    row = Ruflet.responsive_row

    assert_equal [], row.children
    refute row.props.key?("controls")
    assert_equal "start", row.props["alignment"]
    assert_equal({ "xs" => 0, "sm" => 576, "md" => 768, "lg" => 992, "xl" => 1200, "xxl" => 1400 }, row.props["breakpoints"])
    assert_equal 12, row.props["columns"]
    assert_equal 10, row.props["run_spacing"]
    assert_equal 10, row.props["spacing"]
    assert_equal "start", row.props["vertical_alignment"]
  end

  def test_responsive_row_rejects_negative_numeric_layout_props_like_flet
    assert_raises(ArgumentError) { Ruflet.responsive_row(columns: -1) }
    assert_raises(ArgumentError) { Ruflet.responsive_row(run_spacing: -1) }
    assert_raises(ArgumentError) { Ruflet.responsive_row(spacing: -1) }
    assert_raises(ArgumentError) { Ruflet.responsive_row(breakpoints: { phone: -1 }) }
  end
end
