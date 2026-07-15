# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoDatePickerCompatibilityTest < Minitest::Test
  def test_cupertino_date_picker_serializes_current_flet_props
    picker = Ruflet.cupertino_date_picker(
      value: "2026-05-15T09:30:00",
      first_date: "2026-01-01T00:00:00",
      last_date: "2026-12-31T23:59:00",
      bgcolor: "#ABCDEF",
      date_order: "month_day_year",
      date_picker_mode: "date",
      item_extent: 36,
      locale: "en_US",
      maximum_year: 2026,
      minimum_year: 2020,
      minute_interval: 15,
      show_day_of_week: true,
      use_24h_format: true,
      on_change: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "CupertinoDatePicker", patch["_c"]
    assert_equal "2026-05-15T09:30:00", patch["value"]
    assert_equal "2026-01-01T00:00:00", patch["first_date"]
    assert_equal "2026-12-31T23:59:00", patch["last_date"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "month_day_year", patch["date_order"]
    assert_equal "date", patch["date_picker_mode"]
    assert_equal 36, patch["item_extent"]
    assert_equal "en_US", patch["locale"]
    assert_equal 2026, patch["maximum_year"]
    assert_equal 2020, patch["minimum_year"]
    assert_equal 15, patch["minute_interval"]
    assert_equal true, patch["show_day_of_week"]
    assert_equal true, patch["use_24h_format"]
    assert_equal true, patch["on_change"]
  end

  def test_cupertino_date_picker_defaults_match_stable_flet_defaults
    picker = Ruflet.cupertino_date_picker

    assert_equal "date_and_time", picker.props["date_picker_mode"]
    assert_equal 32.0, picker.props["item_extent"]
    assert_equal 1, picker.props["minimum_year"]
    assert_equal 1, picker.props["minute_interval"]
    assert_equal false, picker.props["show_day_of_week"]
    assert_equal false, picker.props["use_24h_format"]
  end

  def test_cupertino_date_picker_rejects_invalid_flet_values
    assert_raises(ArgumentError) { Ruflet.cupertino_date_picker(item_extent: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_date_picker(minute_interval: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_date_picker(minute_interval: 7) }
    assert_raises(ArgumentError) { Ruflet.cupertino_date_picker(date_picker_mode: "time", show_day_of_week: true) }
  end

  def test_cupertino_date_picker_change_event_updates_value_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    picker = Ruflet.cupertino_date_picker(value: "2026-05-15T09:30:00", on_change: ->(event) { observed << [event.value, event.control.props["value"]] })
    page.add(picker)

    page.dispatch_event(target: picker.wire_id, name: "change", data: { "value" => "2026-05-15T10:45:00" })

    assert_equal "2026-05-15T10:45:00", picker.props["value"]
    assert_equal [["2026-05-15T10:45:00", "2026-05-15T10:45:00"]], observed
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoDatePicker", Ruflet.cupertinodatepicker.to_patch["_c"]
  end
end
