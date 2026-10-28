# frozen_string_literal: true

require_relative "test_helper"

class RufletCustomScrollViewCompatibilityTest < Minitest::Test
  def test_custom_scroll_view_serializes_slivers_and_scroll_props
    view = Ruflet.custom_scroll_view(
      [
        Ruflet.sliver_list([Ruflet.text("A")], header: Ruflet.text("Today"), sticky_header: true),
        Ruflet.text("Auto-wrapped box")
      ],
      anchor: 0.25,
      auto_scroll: true,
      cache_extent: 300,
      clip_behavior: "antiAlias",
      expand: true,
      horizontal: false,
      keyboard_dismiss_behavior: "onDrag",
      reverse: true,
      scroll: "auto",
      scroll_interval: 50,
      semantic_child_count: 2,
      on_scroll: ->(_event) {}
    )

    patch = view.to_patch

    assert_equal "CustomScrollView", patch["_c"]
    assert_equal %w[SliverList Text], patch["slivers"].map { |sliver| sliver["_c"] }
    refute patch.key?("controls")
    assert_equal 0.25, patch["anchor"]
    assert_equal true, patch["auto_scroll"]
    assert_equal 300, patch["cache_extent"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal true, patch["expand"]
    assert_equal false, patch["horizontal"]
    assert_equal "onDrag", patch["keyboard_dismiss_behavior"]
    assert_equal true, patch["reverse"]
    assert_equal "auto", patch["scroll"]
    assert_equal 50, patch["scroll_interval"]
    assert_equal 2, patch["semantic_child_count"]
    assert_equal true, patch["on_scroll"]
    assert view.has_handler?(:scroll)
  end

  def test_custom_scroll_view_defaults
    view = Ruflet.custom_scroll_view

    assert_equal "customscrollview", view.type
    assert_equal false, view.props["horizontal"]
    assert_equal false, view.props["reverse"]
    refute view.props.key?("slivers")
    assert_equal [], view.children
  end

  def test_block_children_land_in_controls
    app = Ruflet::DSL.app

    view = app.custom_scroll_view(expand: true) do
      sliver_list { text("One") }
      sliver_grid(runs_count: 2) { text("G1") }
    end

    patch = view.to_patch
    assert_equal %w[SliverList SliverGrid], patch["controls"].map { |child| child["_c"] }
    refute patch.key?("slivers")
    assert_equal ["One"], patch["controls"].first["controls"].map { |child| child["value"] }
    assert_equal ["G1"], patch["controls"].last["controls"].map { |child| child["value"] }
  end

  def test_compact_aliases_use_same_controls
    assert_equal "CustomScrollView", Ruflet.customscrollview.to_patch["_c"]
    assert_equal "SliverList", Ruflet.sliverlist.to_patch["_c"]
    assert_equal "SliverGrid", Ruflet.slivergrid.to_patch["_c"]
    assert_equal "SliverToBoxAdapter", Ruflet.slivertoboxadapter.to_patch["_c"]
    assert_equal "SliverFillRemaining", Ruflet.sliverfillremaining.to_patch["_c"]
    assert_equal "CustomScrollView", Ruflet.control(:custom_scroll_view).to_patch["_c"]
    assert_equal "SliverList", Ruflet.control(:sliver_list).to_patch["_c"]
  end

  def test_sliver_list_serializes_items_header_and_list_props
    header = Ruflet.text("Today")
    list = Ruflet.sliver_list(
      [Ruflet.text("One"), Ruflet.text("Two")],
      bgcolor: "#FFEEDD",
      build_controls_on_demand: false,
      divider_thickness: 1,
      header: header,
      item_extent: 44,
      key: "today",
      padding: { left: 16, right: 16 },
      spacing: 8,
      sticky_header: true
    )

    patch = list.to_patch

    assert_equal "SliverList", patch["_c"]
    assert_equal %w[One Two], patch["controls"].map { |child| child["value"] }
    refute list.props.key?("controls")
    assert_equal "Text", patch["header"]["_c"]
    assert_equal "Today", patch["header"]["value"]
    assert_equal "#ffeedd", patch["bgcolor"]
    assert_equal false, patch["build_controls_on_demand"]
    assert_equal 1, patch["divider_thickness"]
    assert_equal 44, patch["item_extent"]
    assert_equal "today", patch["key"]
    assert_equal({ "left" => 16, "right" => 16 }, patch["padding"])
    assert_equal 8, patch["spacing"]
    assert_equal true, patch["sticky_header"]
  end

  def test_sliver_list_defaults_match_list_view
    list = Ruflet.sliver_list

    assert_equal true, list.props["build_controls_on_demand"]
    assert_equal 0, list.props["divider_thickness"]
    assert_equal 0, list.props["spacing"]
    assert_equal false, list.props["sticky_header"]
  end

  def test_sliver_grid_serializes_and_defaults_match_grid_view
    grid = Ruflet.sliver_grid(
      [Ruflet.text("G1"), Ruflet.text("G2")],
      header: Ruflet.text("Photos"),
      max_extent: 150,
      padding: 8,
      runs_count: 2
    )
    patch = grid.to_patch

    assert_equal "SliverGrid", patch["_c"]
    assert_equal %w[G1 G2], patch["controls"].map { |child| child["value"] }
    assert_equal "Photos", patch["header"]["value"]
    assert_equal 150, patch["max_extent"]
    assert_equal 8, patch["padding"]
    assert_equal 2, patch["runs_count"]
    assert_equal 1.0, patch["child_aspect_ratio"]
    assert_equal 10, patch["run_spacing"]
    assert_equal 10, patch["spacing"]
    assert_equal false, patch["sticky_header"]
  end

  def test_box_slivers_serialize_content
    adapter = Ruflet.sliver_to_box_adapter(Ruflet.text("Box"), key: "box")
    fill = Ruflet.sliver_fill_remaining(Ruflet.text("Empty"), fill_overscroll: true)

    assert_equal "SliverToBoxAdapter", adapter.to_patch["_c"]
    assert_equal "Box", adapter.to_patch["content"]["value"]
    assert_equal "box", adapter.to_patch["key"]
    assert_equal "SliverFillRemaining", fill.to_patch["_c"]
    assert_equal "Empty", fill.to_patch["content"]["value"]
    assert_equal true, fill.to_patch["fill_overscroll"]
    # Ruflet default differs from Flutter: content is box content, not a scrollable.
    assert_equal false, fill.to_patch["has_scroll_body"]
    assert_equal false, Ruflet.sliver_fill_remaining.props["has_scroll_body"]
  end

  def test_sliver_children_only_accept_sliver_keywords
    assert_raises(ArgumentError) { Ruflet.sliver_list(width: 100) }
    assert_raises(ArgumentError) { Ruflet.sliver_grid(on_click: ->(_e) {}) }
    assert_raises(ArgumentError) { Ruflet.sliver_to_box_adapter(Ruflet.text("x"), margin: 4) }
    assert_raises(ArgumentError) { Ruflet.sliver_fill_remaining(expand: true) }
    assert_raises(ArgumentError) { Ruflet.custom_scroll_view(not_a_prop: true) }
    assert_raises(ArgumentError) do
      Ruflet::UI::Controls::RufletComponents::CustomScrollViewControl.new(on_refreshed: ->(_e) {})
    end
  end

  def test_nested_slivers_get_wire_ids_and_patch_independently
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    list = Ruflet.sliver_list([Ruflet.text("One")])
    view = Ruflet.custom_scroll_view([list], expand: true)
    page.add(view)

    refute_nil view.wire_id
    refute_nil list.wire_id
    refute_equal view.wire_id, list.wire_id

    messages.clear
    list.children << Ruflet.text("Two")
    page.update

    # The patch targets the sliver itself, so the client rebuilds only it.
    assert_equal 1, messages.length
    _action, payload = messages.first
    assert_equal list.wire_id, payload["id"]
    assert_includes payload.inspect, "Two"
  end

  def test_scroll_event_dispatches_scroll_payload
    events = []
    view = Ruflet.custom_scroll_view(
      [Ruflet.sliver_list([Ruflet.text("One")])],
      on_scroll: ->(event) { events << [event.name, event.scroll_delta.y] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(view)

    page.dispatch_event(target: view.wire_id, name: "scroll", data: { "scroll_delta" => { "x" => 0, "y" => 12 } })

    assert_equal [["scroll", 12]], events
  end
end
