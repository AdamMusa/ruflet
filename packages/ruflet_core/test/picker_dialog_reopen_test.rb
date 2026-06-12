# frozen_string_literal: true

require_relative "test_helper"

# Regression: a Material/Cupertino picker auto-dismisses on the client once a
# value is confirmed, but only sends a value event (change), never a close.
# The server must mark the dialog closed so show_dialog can reopen it — without
# this, the picker opens once and every later "open" is a silent no-op.
class RufletPickerDialogReopenTest < Minitest::Test
  def make_page
    sent = []
    page = Ruflet::Page.new(session_id: "s", client_details: {}, sender: ->(action, payload) { sent << [action, payload] })
    [page, sent]
  end

  def assert_reopens(control, change_data:)
    page, sent = make_page
    control.on(:change) {}

    page.show_dialog(control)
    assert_equal true, control.props["open"], "first show_dialog should open it"

    page.dispatch_event(target: control.wire_id, name: "change", data: change_data)
    assert_equal false, control.props["open"], "confirming a picker must close it server-side"

    before = sent.length
    page.show_dialog(control)
    assert_equal true, control.props["open"], "second show_dialog should reopen it"
    assert_operator sent.length, :>, before, "reopening must push a patch"
  end

  def test_date_picker_reopens_after_selection
    picker = Ruflet::UI::ControlFactory.build(
      :datepicker, value: "2026-05-21", first_date: "2026-01-01", last_date: "2026-12-31"
    )
    assert_reopens(picker, change_data: "2026-06-10")
  end

  def test_date_range_picker_reopens_after_selection
    picker = Ruflet::UI::ControlFactory.build(
      :daterangepicker, start_value: "2026-05-01", end_value: "2026-05-21",
                        first_date: "2026-01-01", last_date: "2026-12-31"
    )
    assert_reopens(picker, change_data: { "start_value" => "2026-06-02", "end_value" => "2026-06-10" })
  end

  def test_time_picker_reopens_after_selection
    picker = Ruflet::UI::ControlFactory.build(:timepicker, value: "09:30")
    assert_reopens(picker, change_data: "10:45")
  end

  def test_alert_dialog_stays_open_on_change
    # Non-picker dialogs must NOT auto-close on a change event (e.g. a form
    # field changing inside the dialog).
    page, = make_page
    field = Ruflet::UI::ControlFactory.build(:textfield, value: "")
    dialog = Ruflet::UI::ControlFactory.build(
      :alertdialog, open: false, modal: true,
                    title: Ruflet::UI::ControlFactory.build(:text, value: "Edit"),
                    content: field
    )
    page.show_dialog(dialog)
    page.dispatch_event(target: field.wire_id, name: "change", data: "typed")

    assert_equal true, dialog.props["open"], "an alert dialog must stay open while editing"
  end
end
