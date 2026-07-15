# frozen_string_literal: true

require_relative "test_helper"

class RufletGridViewCompatibilityTest < Minitest::Test
  def test_grid_view_accepts_positional_children_and_serializes_current_flet_props
    grid = Ruflet.grid_view(
      [Ruflet.text("One"), Ruflet.text("Two")],
      build_controls_on_demand: false,
      cache_extent: 120,
      child_aspect_ratio: 1.5,
      clip_behavior: "antiAlias",
      horizontal: true,
      max_extent: 160,
      padding: { left: 8 },
      reverse: true,
      run_spacing: 6,
      runs_count: 3,
      scroll: "auto",
      scroll_interval: 50,
      semantic_child_count: 2,
      spacing: 4,
      on_scroll: ->(_event) {}
    )

    patch = grid.to_patch

    assert_equal "GridView", patch["_c"]
    assert_equal ["One", "Two"], grid.children.map { |control| control.props["value"] }
    refute grid.props.key?("controls")
    assert_equal ["One", "Two"], patch["controls"].map { |control| control["value"] }
    assert_equal false, patch["build_controls_on_demand"]
    assert_equal 120, patch["cache_extent"]
    assert_equal 1.5, patch["child_aspect_ratio"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal true, patch["horizontal"]
    assert_equal 160, patch["max_extent"]
    assert_equal({ "left" => 8 }, patch["padding"])
    assert_equal true, patch["reverse"]
    assert_equal 6, patch["run_spacing"]
    assert_equal 3, patch["runs_count"]
    assert_equal "auto", patch["scroll"]
    assert_equal 50, patch["scroll_interval"]
    assert_equal 2, patch["semantic_child_count"]
    assert_equal 4, patch["spacing"]
    assert_equal true, patch["on_scroll"]
  end

  def test_grid_view_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.grid_view(children: [first])
    with_controls_alias = Ruflet.grid_view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_alias_uses_same_control
    grid = Ruflet.gridview([Ruflet.text("One")])

    assert_equal "gridview", grid.type
    assert_equal "GridView", grid.to_patch["_c"]
  end

  def test_grid_view_defaults_match_flet
    grid = Ruflet.grid_view

    assert_equal [], grid.children
    refute grid.props.key?("controls")
    assert_equal true, grid.props["build_controls_on_demand"]
    assert_equal 1.0, grid.props["child_aspect_ratio"]
    assert_equal false, grid.props["horizontal"]
    assert_equal false, grid.props["reverse"]
    assert_equal 10, grid.props["run_spacing"]
    assert_equal 1, grid.props["runs_count"]
    assert_equal 10, grid.props["spacing"]
  end

  def test_grid_view_rejects_negative_numeric_layout_props_like_flet
    assert_raises(ArgumentError) { Ruflet.grid_view(child_aspect_ratio: -1) }
    assert_raises(ArgumentError) { Ruflet.grid_view(max_extent: -1) }
    assert_raises(ArgumentError) { Ruflet.grid_view(run_spacing: -1) }
    assert_raises(ArgumentError) { Ruflet.grid_view(runs_count: -1) }
    assert_raises(ArgumentError) { Ruflet.grid_view(semantic_child_count: -1) }
    assert_raises(ArgumentError) { Ruflet.grid_view(spacing: -1) }
  end

  def test_scroll_event_dispatches_existing_scroll_payload
    events = []
    grid = Ruflet.grid_view(
      [Ruflet.text("One")],
      on_scroll: ->(event) { events << [event.name, event.scroll_delta.x, event.scroll_delta.y] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(grid)

    page.dispatch_event(target: grid.wire_id, name: "scroll", data: { "scroll_delta" => { "x" => 0, "y" => 24 } })

    assert_equal [["scroll", 0, 24]], events
  end
end
