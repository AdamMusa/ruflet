# frozen_string_literal: true

require_relative "test_helper"

class RufletPickerCompatibilityTest < Minitest::Test
  def test_date_picker_serializes_current_flet_props
    picker = Ruflet.date_picker(
      value: "2026-05-14",
      first_date: "2026-01-01",
      last_date: "2026-12-31",
      current_date: "2026-05-01",
      adaptive: true,
      barrier_color: "#ABCDEF",
      cancel_text: "Cancel",
      confirm_text: "OK",
      date_picker_mode: "day",
      entry_mode: "calendar",
      error_format_text: "Bad format",
      error_invalid_text: "Out of range",
      field_hint_text: "mm/dd/yyyy",
      field_label_text: "Date",
      help_text: "Pick a date",
      inset_padding: { left: 16 },
      keyboard_type: "datetime",
      locale: "en_US",
      modal: true,
      open: true,
      switch_to_calendar_icon: "calendar_today",
      switch_to_input_icon: Ruflet.icon("edit"),
      on_change: ->(_event) {},
      on_dismiss: ->(_event) {},
      on_entry_mode_change: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "DatePicker", patch["_c"]
    assert_equal "2026-05-14", patch["value"]
    assert_equal "2026-01-01", patch["first_date"]
    assert_equal "2026-12-31", patch["last_date"]
    assert_equal "2026-05-01", patch["current_date"]
    assert_equal true, patch["adaptive"]
    assert_equal "#abcdef", patch["barrier_color"]
    assert_equal "Cancel", patch["cancel_text"]
    assert_equal "OK", patch["confirm_text"]
    assert_equal "day", patch["date_picker_mode"]
    assert_equal "calendar", patch["entry_mode"]
    assert_equal "Bad format", patch["error_format_text"]
    assert_equal "Out of range", patch["error_invalid_text"]
    assert_equal "mm/dd/yyyy", patch["field_hint_text"]
    assert_equal "Date", patch["field_label_text"]
    assert_equal "Pick a date", patch["help_text"]
    assert_equal({ "left" => 16 }, patch["inset_padding"])
    assert_equal "datetime", patch["keyboard_type"]
    assert_equal "en_US", patch["locale"]
    assert_equal true, patch["modal"]
    assert_equal true, patch["open"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("calendar_today"), patch["switch_to_calendar_icon"]
    assert_equal "Icon", patch["switch_to_input_icon"]["_c"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_dismiss"]
    assert_equal true, patch["on_entry_mode_change"]
  end

  def test_date_range_picker_serializes_current_flet_props
    picker = Ruflet.date_range_picker(
      start_value: "2026-05-01",
      end_value: "2026-05-14",
      first_date: "2026-01-01",
      last_date: "2026-12-31",
      current_date: "2026-05-01",
      barrier_color: "#ABCDEF",
      cancel_text: "Cancel",
      confirm_text: "OK",
      entry_mode: "input",
      error_format_text: "Bad format",
      error_invalid_range_text: "Bad range",
      error_invalid_text: "Out of range",
      field_end_hint_text: "End",
      field_end_label_text: "End date",
      field_start_hint_text: "Start",
      field_start_label_text: "Start date",
      help_text: "Pick a range",
      keyboard_type: "datetime",
      locale: "en_US",
      modal: true,
      open: true,
      save_text: "Save",
      switch_to_calendar_icon: "calendar_today",
      switch_to_input_icon: "edit",
      on_change: ->(_event) {},
      on_dismiss: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "DateRangePicker", patch["_c"]
    assert_equal "2026-05-01", patch["start_value"]
    assert_equal "2026-05-14", patch["end_value"]
    assert_equal "2026-01-01", patch["first_date"]
    assert_equal "2026-12-31", patch["last_date"]
    assert_equal "2026-05-01", patch["current_date"]
    assert_equal "#abcdef", patch["barrier_color"]
    assert_equal "Cancel", patch["cancel_text"]
    assert_equal "OK", patch["confirm_text"]
    assert_equal "input", patch["entry_mode"]
    assert_equal "Bad format", patch["error_format_text"]
    assert_equal "Bad range", patch["error_invalid_range_text"]
    assert_equal "Out of range", patch["error_invalid_text"]
    assert_equal "End", patch["field_end_hint_text"]
    assert_equal "End date", patch["field_end_label_text"]
    assert_equal "Start", patch["field_start_hint_text"]
    assert_equal "Start date", patch["field_start_label_text"]
    assert_equal "Pick a range", patch["help_text"]
    assert_equal "datetime", patch["keyboard_type"]
    assert_equal "en_US", patch["locale"]
    assert_equal true, patch["modal"]
    assert_equal true, patch["open"]
    assert_equal "Save", patch["save_text"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("calendar_today"), patch["switch_to_calendar_icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("edit"), patch["switch_to_input_icon"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_dismiss"]
  end

  def test_time_picker_serializes_current_flet_props
    picker = Ruflet.time_picker(
      value: "19:30",
      adaptive: true,
      barrier_color: "#ABCDEF",
      cancel_text: "Cancel",
      confirm_text: "OK",
      entry_mode: "dial",
      error_invalid_text: "Bad time",
      help_text: "Pick a time",
      hour_format: "h24",
      hour_label_text: "Hour",
      locale: "en_US",
      minute_label_text: "Minute",
      modal: true,
      open: true,
      orientation: "landscape",
      switch_to_input_icon: "keyboard",
      switch_to_timer_icon: "schedule",
      on_change: ->(_event) {},
      on_dismiss: ->(_event) {},
      on_entry_mode_change: ->(_event) {}
    )

    patch = picker.to_patch

    assert_equal "TimePicker", patch["_c"]
    assert_equal "19:30", patch["value"]
    assert_equal true, patch["adaptive"]
    assert_equal "#abcdef", patch["barrier_color"]
    assert_equal "Cancel", patch["cancel_text"]
    assert_equal "OK", patch["confirm_text"]
    assert_equal "dial", patch["entry_mode"]
    assert_equal "Bad time", patch["error_invalid_text"]
    assert_equal "Pick a time", patch["help_text"]
    assert_equal "h24", patch["hour_format"]
    assert_equal "Hour", patch["hour_label_text"]
    assert_equal "en_US", patch["locale"]
    assert_equal "Minute", patch["minute_label_text"]
    assert_equal true, patch["modal"]
    assert_equal true, patch["open"]
    assert_equal "landscape", patch["orientation"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("keyboard"), patch["switch_to_input_icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("schedule"), patch["switch_to_timer_icon"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_dismiss"]
    assert_equal true, patch["on_entry_mode_change"]
  end

  def test_picker_aliases_use_same_controls
    assert_equal "DatePicker", Ruflet.datepicker.to_patch["_c"]
    assert_equal "DateRangePicker", Ruflet.daterangepicker.to_patch["_c"]
    assert_equal "TimePicker", Ruflet.timepicker.to_patch["_c"]
  end

  def test_date_picker_rejects_out_of_range_values_like_flet
    assert_raises(ArgumentError) { Ruflet.date_picker(first_date: "2026-12-31", last_date: "2026-01-01") }
    assert_raises(ArgumentError) { Ruflet.date_picker(first_date: "2026-01-01", last_date: "2026-12-31", value: "2025-12-31") }
    assert_raises(ArgumentError) { Ruflet.date_picker(first_date: "2026-01-01", last_date: "2026-12-31", value: "2027-01-01") }
  end

  def test_date_range_picker_rejects_invalid_ranges_like_flet
    assert_raises(ArgumentError) { Ruflet.date_range_picker(first_date: "2026-12-31", last_date: "2026-01-01") }
    assert_raises(ArgumentError) { Ruflet.date_range_picker(first_date: "2026-01-01", last_date: "2026-12-31", start_value: "2025-12-31") }
    assert_raises(ArgumentError) { Ruflet.date_range_picker(first_date: "2026-01-01", last_date: "2026-12-31", end_value: "2027-01-01") }
    assert_raises(ArgumentError) { Ruflet.date_range_picker(start_value: "2026-05-14", end_value: "2026-05-01") }
  end

  def test_picker_change_events_update_values_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    date_picker = Ruflet.date_picker(value: "2026-05-01", on_change: ->(event) { events << [:date, event.control.props["value"]] })
    range_picker = Ruflet.date_range_picker(
      start_value: "2026-05-01",
      end_value: "2026-05-14",
      on_change: ->(event) { events << [:range, event.control.props["start_value"], event.control.props["end_value"]] }
    )
    time_picker = Ruflet.time_picker(value: "19:30", on_change: ->(event) { events << [:time, event.control.props["value"]] })
    page.add(date_picker, range_picker, time_picker)

    page.dispatch_event(target: date_picker.wire_id, name: "change", data: { "value" => "2026-05-20" })
    page.dispatch_event(target: range_picker.wire_id, name: "change", data: { "start_value" => "2026-05-02", "end_value" => "2026-05-21" })
    page.dispatch_event(target: time_picker.wire_id, name: "change", data: { "value" => "20:15" })

    assert_equal [
      [:date, "2026-05-20"],
      [:range, "2026-05-02", "2026-05-21"],
      [:time, "20:15"]
    ], events
  end
end
