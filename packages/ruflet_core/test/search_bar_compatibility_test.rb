# frozen_string_literal: true

require_relative "test_helper"

class RufletSearchBarCompatibilityTest < Minitest::Test
  def test_search_bar_accepts_positional_children_and_serializes_current_flet_props
    children = [
      Ruflet.text("Blue"),
      Ruflet.text("Black")
    ]
    search_bar = Ruflet.search_bar(
      children,
      autofocus: true,
      bar_bgcolor: { focused: "#ABCDEF" },
      bar_border_side: { color: "#111111", width: 1 },
      bar_elevation: { hovered: 3 },
      bar_hint_text: "Search colors",
      bar_hint_text_style: { size: 12 },
      bar_leading: Ruflet.icon("search"),
      bar_overlay_color: { pressed: "#222222" },
      bar_padding: { left: 8 },
      bar_scroll_padding: { bottom: 16 },
      bar_shadow_color: "#333333",
      bar_shape: { border_radius: 12 },
      bar_size_constraints: { min_width: 120 },
      bar_text_style: { color: "#444444" },
      bar_trailing: [Ruflet.icon("mic")],
      capitalization: "words",
      divider_color: "#555555",
      full_screen: true,
      keyboard_type: "text",
      shrink_wrap: true,
      value: "bl",
      view_bar_padding: { top: 4 },
      view_bgcolor: "#666666",
      view_elevation: 4,
      view_header_height: 64,
      view_header_text_style: { weight: "bold" },
      view_hint_text: "Choose a color",
      view_hint_text_style: { italic: true },
      view_leading: Ruflet.icon("arrow_back"),
      view_padding: { right: 10 },
      view_shape: { border_radius: 6 },
      view_side: { color: "#777777" },
      view_size_constraints: { max_height: 300 },
      view_trailing: [Ruflet.icon("close")],
      on_blur: ->(_event) {},
      on_change: ->(_event) {},
      on_focus: ->(_event) {},
      on_submit: ->(_event) {},
      on_tap: ->(_event) {},
      on_tap_outside_bar: ->(_event) {}
    )

    patch = search_bar.to_patch

    assert_equal "SearchBar", patch["_c"]
    assert_equal children, search_bar.children
    refute search_bar.props.key?("controls")
    assert_equal true, patch["autofocus"]
    assert_equal({ "focused" => "#ABCDEF" }, patch["bar_bgcolor"])
    assert_equal({ "color" => "#111111", "width" => 1 }, patch["bar_border_side"])
    assert_equal({ "hovered" => 3 }, patch["bar_elevation"])
    assert_equal "Search colors", patch["bar_hint_text"]
    assert_equal({ "size" => 12 }, patch["bar_hint_text_style"])
    assert_equal "Icon", patch["bar_leading"]["_c"]
    assert_equal({ "pressed" => "#222222" }, patch["bar_overlay_color"])
    assert_equal({ "left" => 8 }, patch["bar_padding"])
    assert_equal({ "bottom" => 16 }, patch["bar_scroll_padding"])
    assert_equal "#333333", patch["bar_shadow_color"]
    assert_equal({ "border_radius" => 12 }, patch["bar_shape"])
    assert_equal({ "min_width" => 120 }, patch["bar_size_constraints"])
    assert_equal({ "color" => "#444444" }, patch["bar_text_style"])
    assert_equal "Icon", patch["bar_trailing"].first["_c"]
    assert_equal "words", patch["capitalization"]
    assert_equal "#555555", patch["divider_color"]
    assert_equal true, patch["full_screen"]
    assert_equal "text", patch["keyboard_type"]
    assert_equal true, patch["shrink_wrap"]
    assert_equal "bl", patch["value"]
    assert_equal({ "top" => 4 }, patch["view_bar_padding"])
    assert_equal "#666666", patch["view_bgcolor"]
    assert_equal 4, patch["view_elevation"]
    assert_equal 64, patch["view_header_height"]
    assert_equal({ "weight" => "bold" }, patch["view_header_text_style"])
    assert_equal "Choose a color", patch["view_hint_text"]
    assert_equal({ "italic" => true }, patch["view_hint_text_style"])
    assert_equal "Icon", patch["view_leading"]["_c"]
    assert_equal({ "right" => 10 }, patch["view_padding"])
    assert_equal({ "border_radius" => 6 }, patch["view_shape"])
    assert_equal({ "color" => "#777777" }, patch["view_side"])
    assert_equal({ "max_height" => 300 }, patch["view_size_constraints"])
    assert_equal "Icon", patch["view_trailing"].first["_c"]
    assert_equal %w[Text Text], patch["controls"].map { |control| control["_c"] }
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_submit"]
    assert_equal true, patch["on_tap"]
    assert_equal true, patch["on_tap_outside_bar"]
  end

  def test_search_bar_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("Blue")
    second = Ruflet.text("Black")

    with_children = Ruflet.search_bar(children: [first])
    with_controls_alias = Ruflet.search_bar(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_search_bar_defaults_match_flet
    search_bar = Ruflet.search_bar

    assert_equal [], search_bar.children
    refute search_bar.props.key?("controls")
    assert_equal false, search_bar.props["autofocus"]
    assert_equal false, search_bar.props["full_screen"]
    assert_equal "", search_bar.props["value"]
  end

  def test_searchbar_alias_uses_same_control
    assert_equal "SearchBar", Ruflet.searchbar(value: "query").to_patch["_c"]
  end

  def test_search_bar_rejects_negative_numeric_values_like_flet
    %i[bar_elevation view_elevation view_header_height].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.search_bar(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_search_bar_change_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    search_bar = Ruflet.search_bar(value: "old", on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(search_bar)

    page.dispatch_event(target: search_bar.wire_id, name: "change", data: { "value" => "new" })

    assert_equal "new", search_bar.props["value"]
    assert_equal [["new", "new"]], observed
  end

  def test_search_bar_methods_invoke_flet_control_methods
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    search_bar = Ruflet.search_bar(value: "query")
    page.add(search_bar)
    messages.clear

    search_bar.open_view
    search_bar.close_view("chosen")
    search_bar.focus

    assert_equal ["open_view", "close_view", "focus"], messages.map { |_action, payload| payload["name"] }
    assert_equal({ "text" => "chosen" }, messages[1].last["args"])
  end
end
