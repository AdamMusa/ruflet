# frozen_string_literal: true

require_relative "test_helper"

class RufletOutlinedIconButtonCompatibilityTest < Minitest::Test
  def test_outlined_icon_button_accepts_positional_icon_and_serializes_current_flet_props
    button = Ruflet.outlined_icon_button(
      "favorite",
      alignment: { x: 0, y: 0 },
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
      on_blur: ->(_event) {},
      on_click: ->(_event) {},
      on_focus: ->(_event) {},
      on_hover: ->(_event) {},
      on_long_press: ->(_event) {}
    )

    patch = button.to_patch

    assert_equal "OutlinedIconButton", patch["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("favorite"), patch["icon"]
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
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
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_hover"]
    assert_equal true, patch["on_long_press"]
  end

  def test_outlined_icon_button_defaults_match_flet
    button = Ruflet.outlined_icon_button("favorite")

    assert_equal "center", button.props["alignment"]
    assert_equal false, button.props["autofocus"]
    assert_equal 24, button.props["icon_size"]
    assert_equal({ "all" => 8 }, button.props["padding"])
  end

  def test_outlined_icon_button_rejects_non_positive_splash_radius_like_flet
    assert_raises(ArgumentError) { Ruflet.outlined_icon_button("favorite", splash_radius: 0) }
    assert_raises(ArgumentError) { Ruflet.outlined_icon_button("favorite", splash_radius: -1) }
  end

  def test_compact_alias_uses_same_control
    assert_equal "OutlinedIconButton", Ruflet.outlinediconbutton("favorite").to_patch["_c"]
  end
end
