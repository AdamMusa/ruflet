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

  def test_navigation_dismisses_an_open_picker_dialog
    page, = make_page
    picker = Ruflet::UI::ControlFactory.build(:datepicker, value: "2026-05-21")
    picker.on(:change) {}
    page.show_dialog(picker)
    assert_equal 1, page.instance_variable_get(:@dialogs_container).props["controls"].length

    # User navigates away without selecting — the dialog must not ghost onto
    # the next view.
    page.dispatch_event(target: 1, name: "route_change", data: "/home")

    assert_empty page.instance_variable_get(:@dialogs), "navigation must untrack open dialogs"
    assert_equal 0, page.instance_variable_get(:@dialogs_container).props["controls"].length
    assert_equal false, picker.props["open"]
  end

  def test_picker_reopens_on_a_fresh_view_after_navigation
    page, = make_page
    first = Ruflet::UI::ControlFactory.build(:timepicker, value: "09:30")
    first.on(:change) {}
    page.show_dialog(first)
    page.dispatch_event(target: 1, name: "route_change", data: "/elsewhere")

    # A new picker built on the new view opens normally.
    second = Ruflet::UI::ControlFactory.build(:timepicker, value: "10:00")
    second.on(:change) {}
    page.show_dialog(second)

    assert_equal true, second.props["open"]
    assert_equal 1, page.instance_variable_get(:@dialogs_container).props["controls"].length
  end

  def test_closing_a_nested_picker_does_not_remount_the_parent_dialog
    page, sent = make_page

    # A form dialog with a picker opened on top of it (nested).
    form = Ruflet::UI::ControlFactory.build(:alertdialog, open: false, modal: true,
                                            title: Ruflet::UI::ControlFactory.build(:text, value: "Form"))
    page.show_dialog(form)
    picker = Ruflet::UI::ControlFactory.build(:datepicker, value: "2026-05-01")
    picker.on(:change) {}
    page.show_dialog(picker)
    container = page.instance_variable_get(:@dialogs_container)
    page.instance_variable_set(:@dialogs_container_mounted, true)
    sent.clear

    # Confirming the picker closes it but the form remains.
    page.dispatch_event(target: picker.wire_id, name: "change", data: "2026-06-10")

    assert_includes page.instance_variable_get(:@dialogs), form, "form must stay tracked"
    assert_equal true, form.props["open"], "form must stay open"
    refute_includes page.instance_variable_get(:@dialogs), picker, "picker must be removed"

    # The remaining dialog is patched in place, never via a full view re-render
    # that would remount (and break) the still-open form on the client.
    assert page.instance_variable_get(:@dialogs_container_mounted),
           "closing a nested dialog must not unmount the dialogs container"
    container_patch = sent.find do |(action, payload)|
      action == Ruflet::Protocol::ACTIONS[:patch_control] &&
        payload.is_a?(Hash) && payload["id"] == container.wire_id
    end
    refute_nil container_patch, "expected an in-place dialogs-container patch"
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
