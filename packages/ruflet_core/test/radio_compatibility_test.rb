# frozen_string_literal: true

require_relative "test_helper"

class RufletRadioCompatibilityTest < Minitest::Test
  def test_radio_serializes_current_flet_props_with_snake_case_keys
    radio = Ruflet.radio(
      label: "Red",
      label_position: "right",
      label_style: { size: 14 },
      value: "red",
      autofocus: true,
      fill_color: { selected: "#ABCDEF" },
      active_color: "#123456",
      overlay_color: { hovered: "#111111" },
      hover_color: "#222222",
      focus_color: "#333333",
      splash_radius: 20,
      toggleable: true,
      visual_density: "compact",
      mouse_cursor: "click"
    )

    patch = radio.to_patch

    assert_equal "Radio", patch["_c"]
    assert_equal "Red", patch["label"]
    assert_equal "right", patch["label_position"]
    assert_equal({ "size" => 14 }, patch["label_style"])
    assert_equal "red", patch["value"]
    assert_equal true, patch["autofocus"]
    assert_equal({ "selected" => "#ABCDEF" }, patch["fill_color"])
    assert_equal "#123456", patch["active_color"]
    assert_equal({ "hovered" => "#111111" }, patch["overlay_color"])
    assert_equal "#222222", patch["hover_color"]
    assert_equal "#333333", patch["focus_color"]
    assert_equal 20, patch["splash_radius"]
    assert_equal true, patch["toggleable"]
    assert_equal "compact", patch["visual_density"]
    assert_equal "click", patch["mouse_cursor"]
  end

  def test_radio_group_accepts_content_as_first_argument_like_flet
    content = Ruflet.column([
      Ruflet.radio(label: "Red", value: "red"),
      Ruflet.radio(label: "Blue", value: "blue")
    ])

    group = Ruflet.radio_group(content, value: "red")
    patch = group.to_patch

    assert_equal "RadioGroup", patch["_c"]
    assert_equal "red", patch["value"]
    assert_equal "Column", patch["content"]["_c"]
    assert_equal ["red", "blue"], patch["content"]["controls"].map { |radio| radio["value"] }
  end

  def test_radio_group_change_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    group = Ruflet.radio_group(value: "red", on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(group)

    page.dispatch_event(target: group.wire_id, name: "change", data: { "value" => "blue" })

    assert_equal "blue", group.props["value"]
    assert_equal [["blue", "blue"]], observed
  end
end
