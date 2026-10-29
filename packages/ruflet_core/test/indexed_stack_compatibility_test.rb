# frozen_string_literal: true

require_relative "test_helper"

class RufletIndexedStackCompatibilityTest < Minitest::Test
  def test_indexed_stack_accepts_positional_children_and_serializes_props
    home = Ruflet.text("Home")
    search = Ruflet.text("Search")

    control = Ruflet.indexed_stack(
      [home, search],
      index: 1,
      alignment: { x: 0, y: 0 },
      fit: "expand",
      clip_behavior: "antiAlias",
      expand: true,
      width: 320,
      height: 200
    )

    patch = control.to_patch

    assert_equal "IndexedStack", patch["_c"]
    assert_equal [home, search], control.children
    refute control.props.key?("controls")
    assert_equal %w[Home Search], patch["controls"].map { |child| child["value"] }
    assert_equal 1, patch["index"]
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal "expand", patch["fit"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal true, patch["expand"]
    assert_equal 320, patch["width"]
    assert_equal 200, patch["height"]
  end

  def test_compact_alias_and_controls_keyword_use_same_control
    child = Ruflet.text("Only")
    control = Ruflet.indexedstack(controls: [child])

    assert_equal "indexedstack", control.type
    assert_equal "IndexedStack", control.to_patch["_c"]
    assert_equal [child], control.children
    assert_equal "IndexedStack", Ruflet.control(:indexed_stack).to_patch["_c"]
    assert_respond_to Ruflet::DSL, :indexed_stack
    assert_respond_to Ruflet::DSL, :indexedstack
  end

  def test_block_children_are_collected_in_order
    control = Ruflet.indexed_stack(index: 0) do
      text("First")
      text("Second")
    end

    assert_equal %w[First Second], control.to_patch["controls"].map { |child| child["value"] }
  end

  def test_index_defaults_to_zero_so_updates_round_trip
    control = Ruflet.indexed_stack

    assert_equal 0, control.props["index"]
    assert_equal [], control.children
    assert_nil control.props["fit"]
    assert_nil control.props["clip_behavior"]
  end

  def test_layout_events_are_registered
    control = Ruflet.indexed_stack(on_size_change: ->(_event) {}, on_animation_end: ->(_event) {})

    assert control.has_handler?(:size_change)
    assert control.has_handler?(:animation_end)
    assert_equal true, control.to_patch["on_size_change"]
  end

  def test_unknown_keyword_raises
    error = assert_raises(ArgumentError) { Ruflet.indexed_stack(selected_index: 1) }

    assert_includes error.message, "selected_index"
  end

  def test_page_update_switches_index
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    body = Ruflet.indexed_stack([Ruflet.text("A"), Ruflet.text("B")])
    page.add(body)
    messages.clear

    page.update(body, index: 1)

    assert_equal 1, body.props["index"]
    refute_empty messages
  end
end
