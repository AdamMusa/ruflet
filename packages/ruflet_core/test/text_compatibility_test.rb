# frozen_string_literal: true

require_relative "test_helper"

class RufletTextCompatibilityTest < Minitest::Test
  def test_text_accepts_current_flet_props_and_serializes_snake_case_keys
    text = Ruflet.text(
      "hello",
      spans: [Ruflet::UI::Controls::RufletComponents::TextSpanControl.new(text: " world")],
      text_align: "center",
      font_family: "Inter",
      font_family_fallback: ["Arial"],
      size: 18,
      weight: "bold",
      italic: true,
      style: "body_medium",
      theme_style: "title_large",
      max_lines: 2,
      overflow: "ellipsis",
      selectable: true,
      no_wrap: true,
      color: "#ABCDEF",
      bgcolor: "#123456",
      semantics_label: "Greeting",
      show_selection_cursor: true,
      enable_interactive_selection: false,
      selection_cursor_width: 3,
      selection_cursor_height: 24,
      selection_cursor_color: "#FEDCBA"
    )

    patch = text.to_patch

    assert_equal "Text", patch["_c"]
    assert_equal "hello", patch["value"]
    assert_equal "center", patch["text_align"]
    assert_equal "Inter", patch["font_family"]
    assert_equal ["Arial"], patch["font_family_fallback"]
    assert_equal 18, patch["size"]
    assert_equal "bold", patch["weight"]
    assert_equal true, patch["italic"]
    assert_equal "body_medium", patch["style"]
    assert_equal "title_large", patch["theme_style"]
    assert_equal 2, patch["max_lines"]
    assert_equal "ellipsis", patch["overflow"]
    assert_equal true, patch["selectable"]
    assert_equal true, patch["no_wrap"]
    assert_equal "#abcdef", patch["color"]
    assert_equal "#123456", patch["bgcolor"]
    assert_equal "Greeting", patch["semantics_label"]
    assert_equal true, patch["show_selection_cursor"]
    assert_equal false, patch["enable_interactive_selection"]
    assert_equal 3, patch["selection_cursor_width"]
    assert_equal 24, patch["selection_cursor_height"]
    assert_equal "#fedcba", patch["selection_cursor_color"]
    assert_equal "TextSpan", patch["spans"].first["_c"]
  end

  def test_text_accepts_flet_tap_and_selection_events
    tapped = []
    selected = []
    text = Ruflet.text(
      "select me",
      on_tap: ->(_e) { tapped << :tap },
      on_selection_change: ->(_e) { selected << :selection }
    )

    patch = text.to_patch

    assert_equal true, patch["on_tap"]
    assert_equal true, patch["on_selection_change"]
    assert text.has_handler?("tap")
    assert text.has_handler?("selection_change")

    text.emit("tap", nil)
    text.emit("selection_change", nil)

    assert_equal [:tap], tapped
    assert_equal [:selection], selected
  end
end
