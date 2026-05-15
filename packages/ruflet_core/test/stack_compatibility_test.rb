# frozen_string_literal: true

require_relative "test_helper"

class RufletStackCompatibilityTest < Minitest::Test
  def test_stack_accepts_positional_children_and_serializes_current_flet_props
    first = Ruflet.button(content: "Back")
    second = Ruflet.button(content: "Front", left: 8, top: 12)

    stack = Ruflet.stack(
      [first, second],
      alignment: { x: 0, y: 1 },
      clip_behavior: "antiAlias",
      fit: "expand",
      width: 200,
      height: 120
    )

    patch = stack.to_patch

    assert_equal "Stack", patch["_c"]
    assert_equal [first, second], stack.children
    refute stack.props.key?("controls")
    assert_equal ["Back", "Front"], patch["controls"].map { |control| control["content"] }
    assert_equal({ "x" => 0, "y" => 1 }, patch["alignment"])
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal "expand", patch["fit"]
    assert_equal 200, patch["width"]
    assert_equal 120, patch["height"]
  end

  def test_stack_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("Back")
    second = Ruflet.text("Front")

    with_children = Ruflet.stack(children: [first])
    with_controls_alias = Ruflet.stack(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_stack_defaults_match_flet
    stack = Ruflet.stack

    assert_equal [], stack.children
    refute stack.props.key?("controls")
    assert_nil stack.props["alignment"]
    assert_equal "hardEdge", stack.props["clip_behavior"]
    assert_equal "loose", stack.props["fit"]
  end
end
