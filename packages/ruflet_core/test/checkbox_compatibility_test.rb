# frozen_string_literal: true

require_relative "test_helper"

class RufletCheckboxCompatibilityTest < Minitest::Test
  def test_checkbox_serializes_current_flet_props_with_snake_case_keys
    checkbox = Ruflet.checkbox(
      label: "Accept",
      value: false,
      label_position: "right",
      label_style: { size: 14 },
      tristate: true,
      autofocus: true,
      fill_color: "#ABCDEF",
      overlay_color: { hovered: "#111111" },
      check_color: "#FEDCBA",
      active_color: "#123456",
      hover_color: "#222222",
      focus_color: "#333333",
      semantics_label: "Accept terms",
      shape: "rounded_rectangle",
      splash_radius: 24,
      border_side: { width: 2 },
      error: true,
      visual_density: "compact",
      mouse_cursor: "click"
    )

    patch = checkbox.to_patch

    assert_equal "Checkbox", patch["_c"]
    assert_equal "Accept", patch["label"]
    assert_equal false, patch["value"]
    assert_equal "right", patch["label_position"]
    assert_equal({ "size" => 14 }, patch["label_style"])
    assert_equal true, patch["tristate"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["fill_color"]
    assert_equal({ "hovered" => "#111111" }, patch["overlay_color"])
    assert_equal "#fedcba", patch["check_color"]
    assert_equal "#123456", patch["active_color"]
    assert_equal "#222222", patch["hover_color"]
    assert_equal "#333333", patch["focus_color"]
    assert_equal "Accept terms", patch["semantics_label"]
    assert_equal "rounded_rectangle", patch["shape"]
    assert_equal 24, patch["splash_radius"]
    assert_equal({ "width" => 2 }, patch["border_side"])
    assert_equal true, patch["error"]
    assert_equal "compact", patch["visual_density"]
    assert_equal "click", patch["mouse_cursor"]
  end

  def test_checkbox_change_event_updates_control_value_before_handler
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    observed = []
    checkbox = Ruflet.checkbox(
      label: "Accept",
      value: false,
      on_change: ->(event) { observed << [event.value, event.control.props["value"]] }
    )
    page.add(checkbox)

    page.dispatch_event(target: checkbox.wire_id, name: "change", data: { "value" => true })

    assert_equal true, checkbox.props["value"]
    assert_equal [[true, true]], observed
  end
end
