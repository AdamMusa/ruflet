# frozen_string_literal: true

require_relative "test_helper"

class RufletSwitchCompatibilityTest < Minitest::Test
  def test_switch_helper_serializes_current_flet_props_with_snake_case_keys
    switch = Ruflet.switch(
      label: "Dark mode",
      label_position: "right",
      label_text_style: { size: 14 },
      value: false,
      autofocus: true,
      active_color: "#ABCDEF",
      active_track_color: "#111111",
      focus_color: "#222222",
      inactive_thumb_color: "#333333",
      inactive_track_color: "#444444",
      thumb_color: { selected: "#555555" },
      thumb_icon: { selected: "add" },
      track_color: { hovered: "#666666" },
      adaptive: true,
      hover_color: "#777777",
      splash_radius: 20,
      overlay_color: { focused: "#888888" },
      track_outline_color: { disabled: "#999999" },
      track_outline_width: { selected: 2 },
      mouse_cursor: "click",
      padding: { left: 1, top: 2, right: 3, bottom: 4 }
    )

    patch = switch.to_patch

    assert_equal "Switch", patch["_c"]
    assert_equal "Dark mode", patch["label"]
    assert_equal "right", patch["label_position"]
    assert_equal({ "size" => 14 }, patch["label_text_style"])
    assert_equal false, patch["value"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#111111", patch["active_track_color"]
    assert_equal "#222222", patch["focus_color"]
    assert_equal "#333333", patch["inactive_thumb_color"]
    assert_equal "#444444", patch["inactive_track_color"]
    assert_equal({ "selected" => "#555555" }, patch["thumb_color"])
    assert_equal({ "selected" => 65604 }, patch["thumb_icon"])
    assert_equal({ "hovered" => "#666666" }, patch["track_color"])
    assert_equal true, patch["adaptive"]
    assert_equal "#777777", patch["hover_color"]
    assert_equal 20, patch["splash_radius"]
    assert_equal({ "focused" => "#888888" }, patch["overlay_color"])
    assert_equal({ "disabled" => "#999999" }, patch["track_outline_color"])
    assert_equal({ "selected" => 2 }, patch["track_outline_width"])
    assert_equal "click", patch["mouse_cursor"]
    assert_equal({ "left" => 1, "top" => 2, "right" => 3, "bottom" => 4 }, patch["padding"])
  end

  def test_switch_change_event_updates_control_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    switch = Ruflet.switch(value: false, on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(switch)

    page.dispatch_event(target: switch.wire_id, name: "change", data: { "value" => true })

    assert_equal true, switch.props["value"]
    assert_equal [[true, true]], observed
  end
end
