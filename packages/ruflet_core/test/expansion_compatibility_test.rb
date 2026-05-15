# frozen_string_literal: true

require_relative "test_helper"

class RufletExpansionCompatibilityTest < Minitest::Test
  def test_expansion_tile_accepts_positional_children_and_serializes_current_flet_props
    children = [
      Ruflet.text("First child"),
      Ruflet.text("Second child")
    ]
    tile = Ruflet.expansion_tile(
      children,
      title: Ruflet.text("Details"),
      subtitle: Ruflet.text("Tap to expand"),
      leading: Ruflet.icon("info"),
      trailing: Ruflet.icon("expand_more"),
      adaptive: true,
      affinity: "trailing",
      animation_style: { duration: 200 },
      bgcolor: "#ABCDEF",
      clip_behavior: "antiAlias",
      collapsed_bgcolor: "#111111",
      collapsed_icon_color: "#222222",
      collapsed_shape: { border_radius: 4 },
      collapsed_text_color: "#333333",
      controls_padding: { left: 8 },
      dense: true,
      enable_feedback: false,
      expanded: true,
      expanded_alignment: { x: 0, y: 1 },
      expanded_cross_axis_alignment: "stretch",
      icon_color: "#444444",
      maintain_state: true,
      min_tile_height: 48,
      shape: { border_radius: 8 },
      show_trailing_icon: true,
      text_color: "#555555",
      tile_padding: { right: 12 },
      visual_density: "compact",
      on_change: ->(_event) {}
    )

    patch = tile.to_patch

    assert_equal "ExpansionTile", patch["_c"]
    assert_equal children, tile.children
    refute tile.props.key?("controls")
    assert_equal %w[Text Text], patch["controls"].map { |control| control["_c"] }
    assert_equal "Text", patch["title"]["_c"]
    assert_equal "Text", patch["subtitle"]["_c"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal "Icon", patch["trailing"]["_c"]
    assert_equal true, patch["adaptive"]
    assert_equal "trailing", patch["affinity"]
    assert_equal({ "duration" => 200 }, patch["animation_style"])
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal "#111111", patch["collapsed_bgcolor"]
    assert_equal "#222222", patch["collapsed_icon_color"]
    assert_equal({ "border_radius" => 4 }, patch["collapsed_shape"])
    assert_equal "#333333", patch["collapsed_text_color"]
    assert_equal({ "left" => 8 }, patch["controls_padding"])
    assert_equal true, patch["dense"]
    assert_equal false, patch["enable_feedback"]
    assert_equal true, patch["expanded"]
    assert_equal({ "x" => 0, "y" => 1 }, patch["expanded_alignment"])
    assert_equal "stretch", patch["expanded_cross_axis_alignment"]
    assert_equal "#444444", patch["icon_color"]
    assert_equal true, patch["maintain_state"]
    assert_equal 48, patch["min_tile_height"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal true, patch["show_trailing_icon"]
    assert_equal "#555555", patch["text_color"]
    assert_equal({ "right" => 12 }, patch["tile_padding"])
    assert_equal "compact", patch["visual_density"]
    assert_equal true, patch["on_change"]
  end

  def test_expansion_panel_list_accepts_positional_children_and_serializes_props
    panel = Ruflet.expansion_panel(
      header: Ruflet.text("Shipping"),
      content: Ruflet.text("123 Market Street"),
      bgcolor: "#ABCDEF",
      can_tap_header: true,
      expanded: true,
      highlight_color: "#111111",
      splash_color: "#222222"
    )
    panel_list = Ruflet.expansion_panel_list(
      [panel],
      divider_color: "#333333",
      elevation: 2,
      expand_icon_color: "#444444",
      expanded_header_padding: { top: 8 },
      spacing: 12,
      on_change: ->(_event) {}
    )

    patch = panel_list.to_patch

    assert_equal "ExpansionPanelList", patch["_c"]
    assert_equal [panel], panel_list.children
    refute panel_list.props.key?("controls")
    assert_equal "#333333", patch["divider_color"]
    assert_equal 2, patch["elevation"]
    assert_equal "#444444", patch["expand_icon_color"]
    assert_equal({ "top" => 8 }, patch["expanded_header_padding"])
    assert_equal 12, patch["spacing"]
    assert_equal true, patch["on_change"]

    panel = patch["controls"].first
    assert_equal "ExpansionPanel", panel["_c"]
    assert_equal "Text", panel["header"]["_c"]
    assert_equal "Text", panel["content"]["_c"]
    assert_equal "#abcdef", panel["bgcolor"]
    assert_equal true, panel["can_tap_header"]
    assert_equal true, panel["expanded"]
    assert_equal "#111111", panel["highlight_color"]
    assert_equal "#222222", panel["splash_color"]
  end

  def test_expansion_controls_accept_children_keyword_and_controls_alias
    tile_child = Ruflet.text("Tile child")
    panel = Ruflet.expansion_panel(header: Ruflet.text("Header"), content: Ruflet.text("Body"))

    tile_with_children = Ruflet.expansion_tile(children: [tile_child], title: Ruflet.text("Title"))
    tile_with_controls_alias = Ruflet.expansion_tile(controls: [tile_child], title: Ruflet.text("Title"))
    list_with_children = Ruflet.expansion_panel_list(children: [panel])
    list_with_controls_alias = Ruflet.expansion_panel_list(controls: [panel])

    assert_equal [tile_child], tile_with_children.children
    assert_equal [tile_child], tile_with_controls_alias.children
    assert_equal [panel], list_with_children.children
    assert_equal [panel], list_with_controls_alias.children
    refute tile_with_children.props.key?("controls")
    refute tile_with_controls_alias.props.key?("controls")
    refute list_with_children.props.key?("controls")
    refute list_with_controls_alias.props.key?("controls")
  end

  def test_expansion_defaults_match_flet
    tile = Ruflet.expansion_tile(title: Ruflet.text("Title"))
    panel_list = Ruflet.expansion_panel_list

    assert_equal [], tile.children
    assert_equal [], panel_list.children
    refute tile.props.key?("controls")
    refute panel_list.props.key?("controls")
    assert_equal false, tile.props["expanded"]
    assert_equal false, tile.props["maintain_state"]
    assert_equal true, tile.props["show_trailing_icon"]
    assert_equal 2, panel_list.props["elevation"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "ExpansionTile", Ruflet.expansiontile(title: Ruflet.text("Title")).to_patch["_c"]
    assert_equal "ExpansionPanel", Ruflet.expansionpanel(header: Ruflet.text("Header"), content: Ruflet.text("Body")).to_patch["_c"]
    assert_equal "ExpansionPanelList", Ruflet.expansionpanellist([Ruflet.expansionpanel(header: Ruflet.text("Header"), content: Ruflet.text("Body"))]).to_patch["_c"]
  end

  def test_expansion_controls_require_visible_required_content_like_flet
    assert_raises(ArgumentError) { Ruflet.expansion_tile }
    assert_raises(ArgumentError) { Ruflet.expansion_tile(title: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel(content: Ruflet.text("Body")) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel(header: Ruflet.text("Header")) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel(header: Ruflet.text("Hidden", visible: false), content: Ruflet.text("Body")) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel(header: Ruflet.text("Header"), content: Ruflet.text("Hidden", visible: false)) }
  end

  def test_expansion_controls_reject_negative_numeric_values_like_flet
    assert_raises(ArgumentError) { Ruflet.expansion_tile(title: Ruflet.text("Title"), min_tile_height: -1) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel_list([Ruflet.expansion_panel(header: Ruflet.text("Header"), content: Ruflet.text("Body"))], elevation: -1) }
    assert_raises(ArgumentError) { Ruflet.expansion_panel_list([Ruflet.expansion_panel(header: Ruflet.text("Header"), content: Ruflet.text("Body"))], spacing: -1) }
  end

  def test_expansion_tile_change_event_updates_expanded_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    tile = Ruflet.expansion_tile(
      title: Ruflet.text("Details"),
      expanded: false,
      on_change: ->(event) { observed << [event.value, event.control.props["expanded"]] }
    )
    page.add(tile)

    page.dispatch_event(target: tile.wire_id, name: "change", data: { "value" => true })

    assert_equal true, tile.props["expanded"]
    assert_equal [[true, true]], observed
  end
end
