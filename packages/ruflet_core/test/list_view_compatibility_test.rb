# frozen_string_literal: true

require_relative "test_helper"

class RufletListViewCompatibilityTest < Minitest::Test
  def test_list_view_accepts_positional_children_and_serializes_current_flet_props
    list = Ruflet.list_view(
      [Ruflet.text("One"), Ruflet.text("Two")],
      auto_scroll: true,
      build_controls_on_demand: false,
      cache_extent: 120,
      clip_behavior: "antiAlias",
      divider_thickness: 2,
      first_item_prototype: true,
      horizontal: true,
      padding: { left: 8 },
      reverse: true,
      scroll: "auto",
      scroll_interval: 50,
      semantic_child_count: 2,
      spacing: 4,
      on_scroll: ->(_event) {}
    )

    patch = list.to_patch

    assert_equal "ListView", patch["_c"]
    assert_equal ["One", "Two"], list.children.map { |control| control.props["value"] }
    refute list.props.key?("controls")
    assert_equal ["One", "Two"], patch["controls"].map { |control| control["value"] }
    assert_equal true, patch["auto_scroll"]
    assert_equal false, patch["build_controls_on_demand"]
    assert_equal 120, patch["cache_extent"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 2, patch["divider_thickness"]
    assert_equal true, patch["first_item_prototype"]
    assert_equal true, patch["horizontal"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal true, patch["reverse"]
    assert_equal "auto", patch["scroll"]
    assert_equal 50, patch["scroll_interval"]
    assert_equal 2, patch["semantic_child_count"]
    assert_equal 4, patch["spacing"]
    assert_equal true, patch["on_scroll"]
  end

  def test_list_view_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.list_view(children: [first])
    with_controls_alias = Ruflet.list_view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_alias_uses_same_control
    list = Ruflet.listview([Ruflet.text("One")])

    assert_equal "listview", list.type
    assert_equal "ListView", list.to_patch["_c"]
  end

  def test_list_view_defaults_match_flet
    list = Ruflet.list_view

    assert_equal [], list.children
    refute list.props.key?("controls")
    assert_equal true, list.props["build_controls_on_demand"]
    assert_equal 0, list.props["divider_thickness"]
    assert_equal false, list.props["first_item_prototype"]
    assert_equal false, list.props["horizontal"]
    assert_equal false, list.props["reverse"]
    assert_equal 0, list.props["spacing"]
  end

  def test_list_view_rejects_negative_numeric_layout_props_like_flet
    assert_raises(ArgumentError) { Ruflet.list_view(divider_thickness: -1) }
    assert_raises(ArgumentError) { Ruflet.list_view(item_extent: -1) }
    assert_raises(ArgumentError) { Ruflet.list_view(semantic_child_count: -1) }
    assert_raises(ArgumentError) { Ruflet.list_view(spacing: -1) }
  end

  def test_scroll_event_dispatches_existing_scroll_payload
    events = []
    list = Ruflet.list_view(
      [Ruflet.text("One")],
      on_scroll: ->(event) { events << [event.name, event.scroll_delta.x, event.scroll_delta.y] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(list)

    page.dispatch_event(target: list.wire_id, name: "scroll", data: { "scroll_delta" => { "x" => 0, "y" => 24 } })

    assert_equal [["scroll", 0, 24]], events
  end
end
