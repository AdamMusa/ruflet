# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoTimerPickerCompatibilityTest < Minitest::Test
  def test_cupertino_timer_picker_serializes_current_flet_props
    picker = Ruflet.cupertino_timer_picker(
      value: 300,
      alignment: "center",
      bgcolor: "#ABCDEF",
      item_extent: 40,
      minute_interval: 5,
      mode: "hour_minute_seconds",
      second_interval: 10,
      on_change: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "CupertinoTimerPicker", patch["_c"]
    assert_equal 300, patch["value"]
    assert_equal "center", patch["alignment"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal 40, patch["item_extent"]
    assert_equal 5, patch["minute_interval"]
    assert_equal "hour_minute_seconds", patch["mode"]
    assert_equal 10, patch["second_interval"]
    assert_equal true, patch["on_change"]
  end

  def test_cupertino_timer_picker_defaults_match_flet
    picker = Ruflet.cupertino_timer_picker

    assert_equal "center", picker.props["alignment"]
    assert_equal 32.0, picker.props["item_extent"]
    assert_equal 1, picker.props["minute_interval"]
    assert_equal "hour_minute_seconds", picker.props["mode"]
    assert_equal 1, picker.props["second_interval"]
    assert_equal 0, picker.props["value"]
  end

  def test_cupertino_timer_picker_rejects_invalid_flet_values
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(item_extent: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(minute_interval: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(minute_interval: 7) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(second_interval: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(second_interval: 7) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(value: -1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(value: 86_400) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(value: 61, minute_interval: 2) }
    assert_raises(ArgumentError) { Ruflet.cupertino_timer_picker(value: 61, second_interval: 2) }
  end

  def test_cupertino_timer_picker_change_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    picker = Ruflet.cupertino_timer_picker(value: 300, on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(picker)

    page.dispatch_event(target: picker.wire_id, name: "change", data: { "value" => 600 })

    assert_equal 600, picker.props["value"]
    assert_equal [[600, 600]], observed
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoTimerPicker", Ruflet.cupertinotimerpicker.to_patch["_c"]
  end
end
