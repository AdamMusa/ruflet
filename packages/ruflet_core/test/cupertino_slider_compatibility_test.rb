# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoSliderCompatibilityTest < Minitest::Test
  def test_cupertino_slider_serializes_current_flet_props
    slider = Ruflet.cupertino_slider(
      value: 0.6,
      min: 0,
      max: 100,
      divisions: 20,
      active_color: "#ABCDEF",
      thumb_color: "#111111",
      on_change: ->(_event) {},
      on_change_start: ->(_event) {},
      on_change_end: ->(_event) {},
      on_blur: ->(_event) {},
      on_focus: ->(_event) {}
    )

    patch = slider.to_patch

    assert_equal "CupertinoSlider", patch["_c"]
    assert_equal 0.6, patch["value"]
    assert_equal 0, patch["min"]
    assert_equal 100, patch["max"]
    assert_equal 20, patch["divisions"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#111111", patch["thumb_color"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_change_start"]
    assert_equal true, patch["on_change_end"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_focus"]
  end

  def test_cupertino_slider_defaults_match_flet
    slider = Ruflet.cupertino_slider

    assert_equal 0.0, slider.props["min"]
    assert_equal 1.0, slider.props["max"]
  end

  def test_cupertino_slider_rejects_invalid_flet_ranges
    assert_raises(ArgumentError) { Ruflet.cupertino_slider(min: 2, max: 1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_slider(min: 0, max: 1, value: -0.1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_slider(min: 0, max: 1, value: 1.1) }
  end

  def test_cupertino_slider_rejects_non_positive_divisions
    assert_raises(ArgumentError) { Ruflet.cupertino_slider(divisions: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_slider(divisions: -1) }
  end

  def test_cupertino_slider_change_event_updates_control_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    slider = Ruflet.cupertino_slider(value: 0.25, on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(slider)

    page.dispatch_event(target: slider.wire_id, name: "change", data: { "value" => 0.75 })

    assert_equal 0.75, slider.props["value"]
    assert_equal [[0.75, 0.75]], observed
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoSlider", Ruflet.cupertinoslider.to_patch["_c"]
  end
end
