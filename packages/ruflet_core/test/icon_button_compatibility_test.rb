# frozen_string_literal: true

require_relative "test_helper"

class RufletIconButtonCompatibilityTest < Minitest::Test
  def test_icon_button_accepts_positional_icon_and_serializes_current_flet_props
    button = Ruflet.icon_button(
      "favorite",
      alignment: { x: 0, y: 0 },
      autofocus: true,
      bgcolor: "#ABCDEF",
      disabled_color: "#111111",
      enable_feedback: true,
      focus_color: "#222222",
      highlight_color: "#333333",
      hover_color: "#444444",
      icon_color: "#555555",
      icon_size: 32,
      mouse_cursor: "click",
      padding: 8,
      selected: true,
      selected_icon: "favorite_border",
      selected_icon_color: "#666666",
      size_constraints: { min_width: 48 },
      splash_color: "#777777",
      splash_radius: 20,
      style: { shape: "circle" },
      url: "https://example.com",
      visual_density: "compact",
      on_click: ->(_event) {},
      on_hover: ->(_event) {},
      on_long_press: ->(_event) {}
    )

    patch = button.to_patch

    assert_equal "IconButton", patch["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("favorite"), patch["icon"]
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#111111", patch["disabled_color"]
    assert_equal true, patch["enable_feedback"]
    assert_equal "#222222", patch["focus_color"]
    assert_equal "#333333", patch["highlight_color"]
    assert_equal "#444444", patch["hover_color"]
    assert_equal "#555555", patch["icon_color"]
    assert_equal 32, patch["icon_size"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal 8, patch["padding"]
    assert_equal true, patch["selected"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("favorite_border"), patch["selected_icon"]
    assert_equal "#666666", patch["selected_icon_color"]
    assert_equal({ "min_width" => 48 }, patch["size_constraints"])
    assert_equal "#777777", patch["splash_color"]
    assert_equal 20, patch["splash_radius"]
    assert_equal({ "shape" => "circle" }, patch["style"])
    assert_equal "https://example.com", patch["url"]
    assert_equal "compact", patch["visual_density"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_hover"]
    assert_equal true, patch["on_long_press"]
  end

  def test_icon_button_rejects_negative_splash_radius_like_flet
    error = assert_raises(ArgumentError) { Ruflet.icon_button("favorite", splash_radius: -1) }

    assert_match(/splash_radius/, error.message)
  end

  def test_icon_button_click_event_dispatches
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    button = Ruflet.icon_button("favorite", on_click: ->(event) { events << [event.name, event.control.type] })
    page.add(button)

    page.dispatch_event(target: button.wire_id, name: "click", data: nil)

    assert_equal [["click", "iconbutton"]], events
  end
end
