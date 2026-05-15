# frozen_string_literal: true

require_relative "test_helper"

class RufletTextFieldCompatibilityTest < Minitest::Test
  def test_text_field_accepts_value_as_first_argument_like_flet
    changed = []
    submitted = []

    field = Ruflet.text_field(
      "hello",
      selection: { base_offset: 1, extent_offset: 4 },
      keyboard_type: "text",
      multiline: true,
      min_lines: 2,
      max_lines: 5,
      max_length: 20,
      password: true,
      can_reveal_password: true,
      read_only: false,
      shift_enter: true,
      ignore_up_down_keys: true,
      text_align: "center",
      autofocus: true,
      capitalization: "words",
      autocorrect: false,
      enable_suggestions: false,
      smart_dashes_type: "disabled",
      smart_quotes_type: "disabled",
      show_cursor: true,
      cursor_color: "#ABCDEF",
      cursor_error_color: "#FEDCBA",
      cursor_width: 2,
      cursor_height: 18,
      cursor_radius: 3,
      selection_color: "#123456",
      input_filter: { regex_string: "[a-z]+" },
      obscuring_character: "*",
      enable_interactive_selection: true,
      enable_ime_personalized_learning: false,
      can_request_focus: true,
      ignore_pointers: false,
      enable_stylus_handwriting: true,
      animate_cursor_opacity: true,
      always_call_on_tap: true,
      scroll_padding: { left: 1, top: 2, right: 3, bottom: 4 },
      clip_behavior: "anti_alias",
      keyboard_brightness: "dark",
      mouse_cursor: "text",
      strut_style: { font_size: 12 },
      autofill_hints: ["name"],
      on_change: ->(e) { changed << e.value },
      on_submit: ->(e) { submitted << e.value }
    )

    patch = field.to_patch

    assert_equal "TextField", patch["_c"]
    assert_equal "hello", patch["value"]
    assert_equal({ "base_offset" => 1, "extent_offset" => 4 }, patch["selection"])
    assert_equal "text", patch["keyboard_type"]
    assert_equal true, patch["multiline"]
    assert_equal 2, patch["min_lines"]
    assert_equal 5, patch["max_lines"]
    assert_equal 20, patch["max_length"]
    assert_equal true, patch["password"]
    assert_equal true, patch["can_reveal_password"]
    assert_equal false, patch["read_only"]
    assert_equal true, patch["shift_enter"]
    assert_equal true, patch["ignore_up_down_keys"]
    assert_equal "center", patch["text_align"]
    assert_equal true, patch["autofocus"]
    assert_equal "words", patch["capitalization"]
    assert_equal false, patch["autocorrect"]
    assert_equal false, patch["enable_suggestions"]
    assert_equal "disabled", patch["smart_dashes_type"]
    assert_equal "disabled", patch["smart_quotes_type"]
    assert_equal true, patch["show_cursor"]
    assert_equal "#abcdef", patch["cursor_color"]
    assert_equal "#fedcba", patch["cursor_error_color"]
    assert_equal 2, patch["cursor_width"]
    assert_equal 18, patch["cursor_height"]
    assert_equal 3, patch["cursor_radius"]
    assert_equal "#123456", patch["selection_color"]
    assert_equal({ "regex_string" => "[a-z]+" }, patch["input_filter"])
    assert_equal "*", patch["obscuring_character"]
    assert_equal true, patch["enable_interactive_selection"]
    assert_equal false, patch["enable_ime_personalized_learning"]
    assert_equal true, patch["can_request_focus"]
    assert_equal false, patch["ignore_pointers"]
    assert_equal true, patch["enable_stylus_handwriting"]
    assert_equal true, patch["animate_cursor_opacity"]
    assert_equal true, patch["always_call_on_tap"]
    assert_equal({ "left" => 1, "top" => 2, "right" => 3, "bottom" => 4 }, patch["scroll_padding"])
    assert_equal "anti_alias", patch["clip_behavior"]
    assert_equal "dark", patch["keyboard_brightness"]
    assert_equal "text", patch["mouse_cursor"]
    assert_equal({ "font_size" => 12 }, patch["strut_style"])
    assert_equal ["name"], patch["autofill_hints"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_submit"]

    field.emit("change", Ruflet::Event.new(name: "change", target: "1", raw_data: { "value" => "next" }, page: nil, control: field))
    field.emit("submit", Ruflet::Event.new(name: "submit", target: "1", raw_data: { "value" => "done" }, page: nil, control: field))

    assert_equal ["next"], changed
    assert_equal ["done"], submitted
  end

  def test_text_field_keeps_value_keyword
    field = Ruflet.text_field(value: "keyword")

    assert_equal "keyword", field.to_patch["value"]
  end
end
