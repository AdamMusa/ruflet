# frozen_string_literal: true

require_relative "test_helper"

# cupertino_date_picker declares inline: true, and the engine renders an
# inline DatePicker in place. A picker the page presents (show_dialog, open,
# dialog =) is still a modal picker, as in v0.0.23: the engine presents every
# DatePicker hosted directly in the page's Dialogs layer, whatever its
# `inline` says (AdamMusa/ruflet-engine#101,
# test/widgets/date_picker_dialog_presentation_test.dart).
#
# These tests pin the wire that rule reads, so presenting a picker never
# depends on Ruby rewriting the developer's `inline`.
class RufletDatePickerDialogPresentationTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
    @page.add(Ruflet.text("Body"))
    @dialogs = patch_value(@sent.last[1]["patch"], "_dialogs")
  end

  def test_show_dialog_hosts_the_inline_picker_directly_in_the_dialogs_layer
    picker = Ruflet.cupertino_date_picker(value: "2026-05-15T09:30:00", on_change: ->(_e) {})

    @page.show_dialog(picker)

    assert_equal "Dialogs", @dialogs["_c"]
    hosted = dialogs_update_controls
    assert_equal [picker.wire_id], hosted.map { |control| control["_i"] }
    assert_equal "DatePicker", hosted.first["_c"]
    assert_equal true, hosted.first["open"]
    assert_equal true, hosted.first["inline"]
    assert_equal true, picker.props["inline"]
  end

  def test_open_and_dialog_assignment_host_the_picker_the_same_way
    opened = Ruflet.cupertino_date_picker
    @page.open(opened)
    assert_equal [["DatePicker", true, true]], dialogs_update_controls.map { |c| [c["_c"], c["open"], c["inline"]] }

    @page.close(opened)
    assigned = Ruflet.cupertino_date_picker
    @page.dialog = assigned
    hosted = dialogs_update_controls.find { |control| control["_i"] == assigned.wire_id }
    assert_equal "DatePicker", hosted["_c"]
    assert_equal true, hosted["inline"]
  end

  def test_close_dialog_patches_open_on_the_picker_itself
    picker = Ruflet.cupertino_date_picker
    @page.show_dialog(picker)

    @page.close_dialog(picker)

    assert_equal({ "id" => picker.wire_id, "patch" => [[0], [0, 0, "open", false]] }, @sent.last[1])
  end

  def test_bottom_sheet_content_picker_is_nested_in_the_sheet_not_hosted
    picker = Ruflet.cupertino_date_picker
    sheet = Ruflet.bottom_sheet(content: picker)

    @page.show_bottom_sheet(sheet)

    hosted = dialogs_update_controls
    assert_equal ["BottomSheet"], hosted.map { |control| control["_c"] }
    assert_equal picker.wire_id, hosted.first["content"]["_i"]
    assert_equal true, hosted.first["content"]["inline"]
  end

  def test_laid_out_picker_stays_in_the_view_and_out_of_the_dialogs_layer
    picker = Ruflet.cupertino_date_picker(height: 216)
    mark = @sent.size

    @page.add(Ruflet.column(children: [picker]))

    column = latest_view_controls.last
    assert_equal [["DatePicker", true]], column["controls"].map { |c| [c["_c"], c["inline"]] }
    # Nothing sent by the add reaches the Dialogs layer, and the page's
    # Dialogs layer, read back after the add, is still empty.
    assert_empty date_pickers_sent_to_dialogs(@sent[mark..-1])
    assert_empty current_dialogs_controls
  end

  # A picker that is laid out and also presented with show_dialog is sent in
  # both places under one wire id. v0.0.23 sent the same, whether the picker
  # was passed in children: or captured by a DSL block. The engine draws the
  # laid-out copy in place and presents the Dialogs copy (ruflet-engine#101).
  def test_laid_out_picker_shown_with_show_dialog_is_sent_in_both_places_under_one_wire_id
    picker = Ruflet.cupertino_date_picker(height: 216)
    @page.add(Ruflet.column(children: [picker]))
    laid_out = latest_view_controls.last["controls"].first

    @page.show_dialog(picker)

    hosted = dialogs_update_controls
    assert_equal [[picker.wire_id, "DatePicker", true, true]], hosted.map { |c| [c["_i"], c["_c"], c["open"], c["inline"]] }
    assert_equal [picker.wire_id, true], [laid_out["_i"], laid_out["inline"]]

    @page.close_dialog(picker)

    assert_equal({ "id" => picker.wire_id, "patch" => [[0], [0, 0, "open", false]] }, @sent.last[1])
  end

  def test_documented_date_picker_show_dialog_wire_is_unchanged
    picker = Ruflet.date_picker(
      value: "2026-01-15",
      first_date: "2026-01-01",
      last_date: "2026-12-31",
      on_change: ->(_e) {}
    )

    @page.show_dialog(picker)

    assert_equal(
      [{
        "_c" => "DatePicker",
        "_i" => picker.wire_id,
        "value" => "2026-01-15",
        "first_date" => "2026-01-01",
        "last_date" => "2026-12-31",
        "on_change" => true,
        "open" => true
      }],
      dialogs_update_controls
    )
  end

  private

  def dialogs_update_controls
    update = @sent.reverse.find { |_action, payload| payload["id"] == @dialogs["_i"] }
    refute_nil update, "expected a patch of the Dialogs container"
    op = update[1]["patch"].find { |candidate| candidate.is_a?(Array) && candidate[2] == "controls" }
    op[3]
  end

  # The root controls of the latest view patch sent.
  def latest_view_controls
    views = @sent.reverse_each.map { |_action, payload| patch_value(Array(payload["patch"]), "views") }.compact.first
    refute_nil views, "expected a view patch"
    views.first.fetch("controls")
  end

  # DatePicker maps in messages that patch the Dialogs container, or that
  # carry the page's _dialogs layer.
  def date_pickers_sent_to_dialogs(messages)
    messages.flat_map do |_action, payload|
      if payload["id"] == @dialogs["_i"]
        date_pickers_in(payload["patch"])
      else
        Array(payload["patch"]).select { |op| op.is_a?(Array) && op[2] == "_dialogs" }.flat_map { |op| date_pickers_in(op[3]) }
      end
    end
  end

  def date_pickers_in(value)
    case value
    when Hash
      found = value["_c"] == "DatePicker" ? [value] : []
      found + value.values.flat_map { |nested| date_pickers_in(nested) }
    when Array
      value.flat_map { |nested| date_pickers_in(nested) }
    else
      []
    end
  end

  # The page's Dialogs layer as it stands now, as a client registering at
  # this point would receive it.
  def current_dialogs_controls
    @page.register_page_patch.fetch("_dialogs").fetch("controls")
  end

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate.is_a?(Array) && candidate[2] == key }
    op && op[3]
  end
end
