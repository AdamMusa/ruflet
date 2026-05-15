# frozen_string_literal: true

require_relative "test_helper"

class RufletButtonCompatibilityTest < Minitest::Test
  def test_button_serializes_current_flet_props_and_events_with_snake_case_keys
    clicked = []
    hovered = []

    button = Ruflet.button(
      content: "Save",
      icon: "add",
      icon_color: "#ABCDEF",
      color: "#FEDCBA",
      bgcolor: "#123456",
      elevation: 2,
      style: { shape: "rounded_rectangle" },
      autofocus: true,
      clip_behavior: "anti_alias",
      url: "https://flet.dev",
      on_click: ->(_e) { clicked << :click },
      on_hover: ->(_e) { hovered << :hover }
    )

    patch = button.to_patch

    assert_equal "Button", patch["_c"]
    assert_equal "Save", patch["content"]
    assert_equal 65604, patch["icon"]
    assert_equal "#abcdef", patch["icon_color"]
    assert_equal "#fedcba", patch["color"]
    assert_equal "#123456", patch["bgcolor"]
    assert_equal 2, patch["elevation"]
    assert_equal({ "shape" => "rounded_rectangle" }, patch["style"])
    assert_equal true, patch["autofocus"]
    assert_equal "anti_alias", patch["clip_behavior"]
    assert_equal "https://flet.dev", patch["url"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_hover"]

    button.emit("click", nil)
    button.emit("hover", nil)

    assert_equal [:click], clicked
    assert_equal [:hover], hovered
  end

  def test_button_requires_content_or_icon_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.button
    end

    assert_includes error.message, "content"
    assert_includes error.message, "icon"
  end
end
