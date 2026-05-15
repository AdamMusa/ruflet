# frozen_string_literal: true

require_relative "test_helper"

class RufletDropdownCompatibilityTest < Minitest::Test
  def test_dropdown_accepts_positional_options_and_serializes_current_flet_props
    dropdown = Ruflet.dropdown(
      [
        Ruflet.dropdown_option("red", text: "Red", leading_icon: "palette"),
        Ruflet.dropdown_option(text: "Blue", trailing_icon: Ruflet.icon("check"))
      ],
      autofocus: true,
      bgcolor: { focused: "#ABCDEF" },
      border: "outline",
      border_color: "#111111",
      border_radius: 8,
      border_width: 1,
      color: "#222222",
      content_padding: { left: 12 },
      editable: true,
      elevation: 4,
      enable_filter: true,
      enable_search: true,
      error_style: { color: "#333333" },
      error_text: "Required",
      expanded_insets: { left: 4 },
      fill_color: "#444444",
      filled: true,
      focused_border_color: "#555555",
      focused_border_width: 2,
      helper_style: { size: 12 },
      helper_text: "Pick one",
      hint_style: { italic: true },
      hint_text: "Color",
      input_filter: { allow: "[a-z]" },
      label: "Favorite",
      label_style: { weight: "bold" },
      leading_icon: "search",
      menu_height: 240,
      menu_style: { bgcolor: "#666666" },
      menu_width: 300,
      selected_suffix: Ruflet.text("selected"),
      selected_trailing_icon: "done",
      text: "Re",
      text_align: "start",
      text_size: 14,
      text_style: { color: "#777777" },
      trailing_icon: "arrow_drop_down",
      value: "red",
      on_blur: ->(_event) {},
      on_focus: ->(_event) {},
      on_select: ->(_event) {},
      on_text_change: ->(_event) {}
    )

    patch = dropdown.to_patch

    assert_equal "Dropdown", patch["_c"]
    assert_equal true, patch["autofocus"]
    assert_equal({ "focused" => "#ABCDEF" }, patch["bgcolor"])
    assert_equal "outline", patch["border"]
    assert_equal "#111111", patch["border_color"]
    assert_equal 8, patch["border_radius"]
    assert_equal 1, patch["border_width"]
    assert_equal "#222222", patch["color"]
    assert_equal({ "left" => 12 }, patch["content_padding"])
    assert_equal true, patch["editable"]
    assert_equal 4, patch["elevation"]
    assert_equal true, patch["enable_filter"]
    assert_equal true, patch["enable_search"]
    assert_equal({ "color" => "#333333" }, patch["error_style"])
    assert_equal "Required", patch["error_text"]
    assert_equal({ "left" => 4 }, patch["expanded_insets"])
    assert_equal "#444444", patch["fill_color"]
    assert_equal true, patch["filled"]
    assert_equal "#555555", patch["focused_border_color"]
    assert_equal 2, patch["focused_border_width"]
    assert_equal({ "size" => 12 }, patch["helper_style"])
    assert_equal "Pick one", patch["helper_text"]
    assert_equal({ "italic" => true }, patch["hint_style"])
    assert_equal "Color", patch["hint_text"]
    assert_equal({ "allow" => "[a-z]" }, patch["input_filter"])
    assert_equal "Favorite", patch["label"]
    assert_equal({ "weight" => "bold" }, patch["label_style"])
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("search"), patch["leading_icon"]
    assert_equal 240, patch["menu_height"]
    assert_equal({ "bgcolor" => "#666666" }, patch["menu_style"])
    assert_equal 300, patch["menu_width"]
    assert_equal "Text", patch["selected_suffix"]["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("done"), patch["selected_trailing_icon"]
    assert_equal "Re", patch["text"]
    assert_equal "start", patch["text_align"]
    assert_equal 14, patch["text_size"]
    assert_equal({ "color" => "#777777" }, patch["text_style"])
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("arrow_drop_down"), patch["trailing_icon"]
    assert_equal "red", patch["value"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_select"]
    assert_equal true, patch["on_text_change"]

    first, second = patch["options"]
    assert_equal "DropdownOption", first["_c"]
    assert_equal "red", first["key"]
    assert_equal "Red", first["text"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("palette"), first["leading_icon"]
    assert_equal "Blue", second["key"]
    assert_equal "Blue", second["text"]
    assert_equal "Icon", second["trailing_icon"]["_c"]
  end

  def test_dropdown_option_accepts_positional_key_and_applies_flet_fallbacks
    keyed = Ruflet.dropdown_option("red")
    texted = Ruflet.dropdown_option(text: "Blue")

    assert_equal "red", keyed.props["key"]
    assert_equal "red", keyed.props["text"]
    assert_equal "Blue", texted.props["key"]
    assert_equal "Blue", texted.props["text"]
  end

  def test_dropdown_option_requires_key_or_text_like_flet
    error = assert_raises(ArgumentError) { Ruflet.dropdown_option }

    assert_match(/key|text/, error.message)
  end

  def test_dropdown_rejects_negative_numeric_values_like_flet
    %i[border_width elevation focused_border_width menu_height menu_width text_size].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.dropdown([], prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_dropdown_select_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    dropdown = Ruflet.dropdown(
      [Ruflet.dropdown_option("red"), Ruflet.dropdown_option("blue")],
      value: "red",
      on_select: ->(event) { observed << [event.value, event.control.props["value"]] }
    )
    page.add(dropdown)

    page.dispatch_event(target: dropdown.wire_id, name: "select", data: { "value" => "blue" })

    assert_equal "blue", dropdown.props["value"]
    assert_equal [["blue", "blue"]], observed
  end
end
