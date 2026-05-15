# frozen_string_literal: true

require_relative "test_helper"

class RufletSliderCompatibilityTest < Minitest::Test
  def test_slider_helper_serializes_current_flet_props_with_snake_case_keys
    slider = Ruflet.slider(
      value: 0.25,
      label: "{value}%",
      min: 0,
      max: 100,
      divisions: 10,
      round: 1,
      autofocus: true,
      active_color: "#ABCDEF",
      inactive_color: "#111111",
      thumb_color: "#222222",
      interaction: "slide_only",
      secondary_active_color: "#333333",
      overlay_color: { hovered: "#444444" },
      secondary_track_value: 50,
      mouse_cursor: "click",
      padding: { left: 1, top: 2, right: 3, bottom: 4 },
      year_2023: false,
      on_change_start: ->(_e) {},
      on_change_end: ->(_e) {}
    )

    patch = slider.to_patch

    assert_equal "Slider", patch["_c"]
    assert_equal 0.25, patch["value"]
    assert_equal "{value}%", patch["label"]
    assert_equal 0, patch["min"]
    assert_equal 100, patch["max"]
    assert_equal 10, patch["divisions"]
    assert_equal 1, patch["round"]
    assert_equal true, patch["autofocus"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#111111", patch["inactive_color"]
    assert_equal "#222222", patch["thumb_color"]
    assert_equal "slide_only", patch["interaction"]
    assert_equal "#333333", patch["secondary_active_color"]
    assert_equal({ "hovered" => "#444444" }, patch["overlay_color"])
    assert_equal 50, patch["secondary_track_value"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal({ "left" => 1, "top" => 2, "right" => 3, "bottom" => 4 }, patch["padding"])
    assert_equal false, patch["year_2023"]
    assert_equal true, patch["on_change_start"]
    assert_equal true, patch["on_change_end"]
  end

  def test_slider_change_event_updates_control_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    slider = Ruflet.slider(value: 0.25, on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(slider)

    page.dispatch_event(target: slider.wire_id, name: "change", data: { "value" => 0.75 })

    assert_equal 0.75, slider.props["value"]
    assert_equal [[0.75, 0.75]], observed
  end
end
