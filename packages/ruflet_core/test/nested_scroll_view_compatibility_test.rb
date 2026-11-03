# frozen_string_literal: true

require_relative "test_helper"
require "ruflet_ui/ruflet/ui/controls/shared/ruflet_controls"

class RufletNestedScrollViewCompatibilityTest < Minitest::Test
  def page_with(sent = [])
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  def test_serializes_header_slivers_body_and_scroll_props
    view = Ruflet.nested_scroll_view(
      [Ruflet.sliver_app_bar(title: Ruflet.text("Inbox"), pinned: true)],
      body: Ruflet.list_view([Ruflet.text("Row 1")]),
      auto_scroll: false,
      clip_behavior: "antiAlias",
      expand: true,
      float_header_slivers: true,
      horizontal: false,
      reverse: true,
      scroll: "auto",
      scroll_interval: 50,
      on_scroll: ->(_event) {}
    )

    patch = view.to_patch

    assert_equal "NestedScrollView", patch["_c"]
    assert_equal ["SliverAppBar"], patch["header_slivers"].map { |sliver| sliver["_c"] }
    assert_equal true, patch["header_slivers"].first["pinned"]
    assert_equal "ListView", patch["body"]["_c"]
    assert_equal ["Row 1"], patch["body"]["controls"].map { |child| child["value"] }
    refute patch.key?("controls")
    assert_equal false, patch["auto_scroll"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal true, patch["expand"]
    assert_equal true, patch["float_header_slivers"]
    assert_equal false, patch["horizontal"]
    assert_equal true, patch["reverse"]
    assert_equal "auto", patch["scroll"]
    assert_equal 50, patch["scroll_interval"]
    assert_equal true, patch["on_scroll"]
    assert view.has_handler?(:scroll)
  end

  def test_keyword_header_slivers_match_the_positional_form
    bar = Ruflet.sliver_app_bar(title: Ruflet.text("T"))
    body = Ruflet.text("Body")

    view = Ruflet.nested_scroll_view(header_slivers: [bar], body: body)

    assert_equal [bar], view.props["header_slivers"]
    assert_same body, view.props["body"]
  end

  def test_defaults
    view = Ruflet.nested_scroll_view(body: Ruflet.text("Body"))

    assert_equal "nestedscrollview", view.type
    assert_equal "NestedScrollView", view.wire_type
    assert_equal false, view.props["float_header_slivers"]
    assert_equal false, view.props["horizontal"]
    assert_equal false, view.props["reverse"]
    refute view.props.key?("header_slivers")
    refute view.props.key?("scroll")
    assert_equal [], view.children
  end

  def test_block_children_are_the_header_slivers
    app = Ruflet::DSL.app

    view = app.nested_scroll_view(body: app.list_view([app.text("Row")]), expand: true) do
      sliver_app_bar(title: text("Inbox"), pinned: true)
      sliver_to_box_adapter(text("Banner"))
    end

    patch = view.to_patch
    assert_equal %w[SliverAppBar SliverToBoxAdapter], patch["controls"].map { |sliver| sliver["_c"] }
    refute patch.key?("header_slivers")
    assert_equal "ListView", patch["body"]["_c"]
    assert_equal "Inbox", patch["controls"].first["title"]["value"]
  end

  def test_prop_controls_built_in_a_block_are_not_block_children
    app = Ruflet::DSL.app

    column = app.column do
      nested_scroll_view(body: list_view([text("Row")])) do
        sliver_app_bar(title: text("Inbox"), bottom: text("Tabs"))
      end
      nested_scroll_view(
        header_slivers: [sliver_app_bar(title: text("Other"))],
        body: tab_bar_view([list_view([text("A")]), list_view([text("B")])])
      )
    end

    first, second = column.children
    assert_equal %w[NestedScrollView NestedScrollView], column.children.map(&:wire_type)
    assert_equal ["SliverAppBar"], first.children.map(&:wire_type)
    assert_equal "ListView", first.props["body"].wire_type
    assert_equal ["Row"], first.props["body"].children.map { |child| child.props["value"] }
    assert_equal [], first.children.first.children
    assert_equal [], second.children
    assert_equal ["SliverAppBar"], second.props["header_slivers"].map(&:wire_type)
    assert_equal %w[ListView ListView], second.props["body"].children.map(&:wire_type)
  end

  def test_collapsing_header_over_tabs_layout
    app = Ruflet::DSL.app

    layout = app.tabs(length: 2) do
      nested_scroll_view(
        body: tab_bar_view([
          list_view((1..3).map { |i| text("Inbox #{i}") }),
          list_view((1..3).map { |i| text("Sent #{i}") })
        ])
      ) do
        sliver_app_bar(
          title: text("Mail"),
          pinned: true,
          variant: "large",
          bottom: tab_bar(tabs: [tab(label: "Inbox"), tab(label: "Sent")])
        )
      end
    end

    patch = layout.to_patch
    view = patch["controls"].first
    assert_equal "Tabs", patch["_c"]
    assert_equal "NestedScrollView", view["_c"]
    assert_equal ["SliverAppBar"], view["controls"].map { |sliver| sliver["_c"] }
    assert_equal "TabBar", view["controls"].first["bottom"]["_c"]
    assert_equal "TabBarView", view["body"]["_c"]
    assert_equal %w[ListView ListView], view["body"]["controls"].map { |page| page["_c"] }
  end

  def test_names_aliases_and_dsl_entry_points
    body = Ruflet.text("Body")
    %w[nested_scroll_view nestedscrollview].each do |name|
      assert Ruflet::UI::ControlFactory.known_control?(name), name
      assert_equal "NestedScrollView", Ruflet::UI::ControlFactory.build(name, body: body).wire_type, name
      assert_equal "NestedScrollView", Ruflet.public_send(name, body: body).wire_type, "Ruflet.#{name}"
      assert_equal "NestedScrollView", Ruflet::DSL.app.public_send(name, body: body).wire_type, "DSL app #{name}"
    end
    assert_equal "NestedScrollView", Ruflet.control(:nested_scroll_view, body: body).wire_type
    assert_equal "NestedScrollView", nested_scroll_view(body: text("Bare")).wire_type
    assert_equal Ruflet::UI::Controls::RufletComponents::NestedScrollViewControl,
                 Ruflet::UI::Controls::Shared::RufletControls::CLASS_MAP.fetch("nested_scroll_view")
  end

  def test_body_must_be_a_control
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view }
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: nil) }
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: "List") }
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: [Ruflet.text("A")]) }
    error = assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: { "_c" => "ListView" }) }
    assert_includes error.message, "body must be a control"
  end

  def test_unknown_keywords_raise
    body = Ruflet.text("Body")
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: body, slivers: []) }
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: body, anchor: 0.5) }
    assert_raises(ArgumentError) { Ruflet.nested_scroll_view(body: body, on_refresh: ->(_e) {}) }
  end

  def test_body_and_header_slivers_get_wire_ids_and_patch_independently
    sent = []
    page = page_with(sent)
    list = Ruflet.list_view([Ruflet.text("One")])
    bar = Ruflet.sliver_app_bar(title: Ruflet.text("Inbox"))
    view = Ruflet.nested_scroll_view([bar], body: list, expand: true)
    page.add(view)

    ids = [view.wire_id, bar.wire_id, list.wire_id]
    assert ids.none?(&:nil?)
    assert_equal ids.uniq, ids

    sent.clear
    list.children << Ruflet.text("Two")
    page.update

    assert_equal 1, sent.length
    _action, payload = sent.first
    assert_equal list.wire_id, payload["id"]
    assert_includes payload.inspect, "Two"
  end

  def test_scroll_event_dispatches_scroll_payload
    events = []
    view = Ruflet.nested_scroll_view(
      body: Ruflet.list_view([Ruflet.text("One")]),
      on_scroll: ->(event) { events << [event.name, event.data["pixels"], event.data["event_type"]] }
    )
    page = page_with
    page.add(view)

    page.dispatch_event(target: view.wire_id, name: "scroll", data: { "pixels" => 40, "event_type" => "update" })

    assert_equal [["scroll", 40, "update"]], events
  end

  def test_scroll_to_invokes_the_client_scroll_view
    sent = []
    page = page_with(sent)
    view = Ruflet.nested_scroll_view(body: Ruflet.list_view([Ruflet.text("One")]))
    page.add(view)

    view.scroll_to(offset: 0, duration: 300)

    action, payload = sent.last
    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], action
    assert_equal view.wire_id, payload["control_id"]
    assert_equal "scroll_to", payload["name"]
    assert_equal 0, payload["args"]["offset"]
    assert_equal 300, payload["args"]["duration"]
  end
end
