# frozen_string_literal: true

require_relative "test_helper"

class RufletListTileCompatibilityTest < Minitest::Test
  def test_list_tile_serializes_current_flet_props_with_snake_case_keys
    tile = Ruflet.list_tile(
      leading: Ruflet.icon("account_circle"),
      title: "Jane Doe",
      subtitle: "Product Manager",
      trailing: "chevron_right",
      autofocus: true,
      bgcolor: "#ABCDEF",
      content_padding: { left: 16, right: 16 },
      dense: true,
      enable_feedback: true,
      horizontal_spacing: 12,
      hover_color: "#111111",
      icon_color: "#222222",
      is_three_line: true,
      leading_and_trailing_text_style: { size: 12 },
      min_height: 64,
      min_leading_width: 40,
      min_vertical_padding: 8,
      mouse_cursor: "click",
      selected: true,
      selected_color: "#333333",
      selected_tile_color: "#444444",
      shape: { border_radius: 8 },
      splash_color: "#555555",
      style: "drawer",
      subtitle_text_style: { size: 13 },
      text_color: "#666666",
      title_alignment: "center",
      title_text_style: { weight: "bold" },
      toggle_inputs: true,
      url: "https://example.com",
      visual_density: "compact",
      on_click: ->(_event) {},
      on_long_press: ->(_event) {}
    )

    patch = tile.to_patch

    assert_equal "ListTile", patch["_c"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal "Jane Doe", patch["title"]
    assert_equal "Product Manager", patch["subtitle"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("chevron_right"), patch["trailing"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "left" => 16, "right" => 16 }, patch["content_padding"])
    assert_equal true, patch["dense"]
    assert_equal true, patch["enable_feedback"]
    assert_equal 12, patch["horizontal_spacing"]
    assert_equal "#111111", patch["hover_color"]
    assert_equal "#222222", patch["icon_color"]
    assert_equal true, patch["is_three_line"]
    assert_equal({ "size" => 12 }, patch["leading_and_trailing_text_style"])
    assert_equal 64, patch["min_height"]
    assert_equal 40, patch["min_leading_width"]
    assert_equal 8, patch["min_vertical_padding"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal true, patch["selected"]
    assert_equal "#333333", patch["selected_color"]
    assert_equal "#444444", patch["selected_tile_color"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal "#555555", patch["splash_color"]
    assert_equal "drawer", patch["style"]
    assert_equal({ "size" => 13 }, patch["subtitle_text_style"])
    assert_equal "#666666", patch["text_color"]
    assert_equal "center", patch["title_alignment"]
    assert_equal({ "weight" => "bold" }, patch["title_text_style"])
    assert_equal true, patch["toggle_inputs"]
    assert_equal "https://example.com", patch["url"]
    assert_equal "compact", patch["visual_density"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_long_press"]
  end

  def test_listtile_alias_uses_same_control
    assert_equal "ListTile", Ruflet.listtile(title: "One").to_patch["_c"]
  end

  def test_list_tile_requires_subtitle_when_three_line_like_flet
    error = assert_raises(ArgumentError) { Ruflet.list_tile(title: "Jane Doe", is_three_line: true) }

    assert_match(/subtitle/, error.message)
  end

  def test_list_tile_click_and_long_press_events_dispatch
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    tile = Ruflet.list_tile(
      title: "Jane Doe",
      on_click: ->(event) { events << event.name },
      on_long_press: ->(event) { events << event.name }
    )
    page.add(tile)

    page.dispatch_event(target: tile.wire_id, name: "click", data: nil)
    page.dispatch_event(target: tile.wire_id, name: "long_press", data: nil)

    assert_equal ["click", "long_press"], events
  end
end
