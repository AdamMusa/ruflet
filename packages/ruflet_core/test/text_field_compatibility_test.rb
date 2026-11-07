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
  # Flet 1.0.3's TextField.on_paste_files: files pasted into the field.
  def test_text_field_on_paste_files_delivers_pasted_files
    page = Ruflet::Page.new(session_id: "s1", client_details: { "route" => "/" }, sender: ->(_action, _payload) {})
    png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xFF].pack("C*")
    received = []
    material = Ruflet.text_field(on_paste_files: ->(event) { received << event })
    cupertino = Ruflet.cupertino_text_field(on_paste_files: ->(event) { received << event })
    page.add(Ruflet.column([material, cupertino]))

    assert_equal true, material.to_patch["on_paste_files"]
    assert_equal true, cupertino.to_patch["on_paste_files"]
    assert_equal "TextField", cupertino.to_patch["_c"]

    files = [
      # Wire strings arrive UTF-8 tagged, the way the server decodes them.
      { "name" => "image.png", "mime_type" => "image/png", "bytes" => png.dup.force_encoding("UTF-8") },
      { "name" => "notes.txt", "mime_type" => "", "bytes" => [104, 105] }
    ]
    page.dispatch_event(target: material.wire_id, name: "paste_files", data: { "files" => files })
    page.dispatch_event(target: cupertino.wire_id, name: "paste_files", data: { "files" => [] })

    event = received.first
    assert_equal "paste_files", event.name
    assert_equal %w[image.png notes.txt], event.files.map(&:name)
    assert_equal ["image/png", ""], event.files.map(&:mime_type)
    assert_equal png.b, event.files.first.bytes
    assert_equal Encoding::BINARY, event.files.first.bytes.encoding
    assert_equal 9, event.files.first.size
    assert_equal "hi", event.files.last.bytes
    assert_equal event.files, event.value
    assert_equal({ "name" => "notes.txt", "mime_type" => "", "bytes" => "hi" }, event.files.last.to_h)
    assert_equal [], received.last.files
  end

  def test_text_field_on_paste_files_attaches_after_construction
    field = Ruflet.text_field
    field.on(:paste_files) { |_event| nil }

    assert_equal true, field.props["on_paste_files"]
    assert_equal true, Ruflet.cupertino_text_field.on(:paste_files) { |_event| nil }.props["on_paste_files"]
  end
end
