# frozen_string_literal: true

require_relative "test_helper"

class RufletRangeSliderCompatibilityTest < Minitest::Test
  def test_range_slider_helper_serializes_current_flet_props
    slider = Ruflet.range_slider(
      min: 0,
      max: 10,
      start_value: 2,
      end_value: 7,
      divisions: 5,
      round: 1,
      active_color: "#ABCDEF",
      inactive_color: "#111111",
      label: "{value}",
      mouse_cursor: "click",
      overlay_color: { hovered: "#222222" },
      on_change: ->(_event) {},
      on_change_start: ->(_event) {},
      on_change_end: ->(_event) {}
    )

    patch = slider.to_patch

    assert_equal "RangeSlider", patch["_c"]
    assert_equal 0, patch["min"]
    assert_equal 10, patch["max"]
    assert_equal 2, patch["start_value"]
    assert_equal 7, patch["end_value"]
    assert_equal 5, patch["divisions"]
    assert_equal 1, patch["round"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#111111", patch["inactive_color"]
    assert_equal "{value}", patch["label"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal({ "hovered" => "#222222" }, patch["overlay_color"])
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_change_start"]
    assert_equal true, patch["on_change_end"]
  end

  def test_rangeslider_alias_uses_same_control
    assert_equal "RangeSlider", Ruflet.rangeslider(max: 3, start_value: 1, end_value: 2).to_patch["_c"]
  end

  def test_range_slider_rejects_invalid_flet_ranges
    assert_raises(ArgumentError) { Ruflet.range_slider(min: 10, max: 0, start_value: 2, end_value: 7) }
    assert_raises(ArgumentError) { Ruflet.range_slider(min: 0, max: 10, start_value: -1, end_value: 7) }
    assert_raises(ArgumentError) { Ruflet.range_slider(min: 0, max: 10, start_value: 8, end_value: 7) }
    assert_raises(ArgumentError) { Ruflet.range_slider(min: 0, max: 10, start_value: 2, end_value: 11) }
  end

  def test_range_slider_rejects_invalid_flet_discrete_values
    assert_raises(ArgumentError) { Ruflet.range_slider(start_value: 1, end_value: 2, divisions: 0) }
    assert_raises(ArgumentError) { Ruflet.range_slider(start_value: 1, end_value: 2, round: -1) }
    assert_raises(ArgumentError) { Ruflet.range_slider(start_value: 1, end_value: 2, round: 21) }
  end

  def test_range_slider_change_event_updates_start_and_end_values_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    slider = Ruflet.range_slider(
      min: 0,
      max: 10,
      start_value: 2,
      end_value: 7,
      on_change: ->(event) { observed << [event.control.props["start_value"], event.control.props["end_value"]] }
    )
    page.add(slider)

    page.dispatch_event(target: slider.wire_id, name: "change", data: { "start_value" => 3, "end_value" => 8 })

    assert_equal 3, slider.props["start_value"]
    assert_equal 8, slider.props["end_value"]
    assert_equal [[3, 8]], observed
  end
end
