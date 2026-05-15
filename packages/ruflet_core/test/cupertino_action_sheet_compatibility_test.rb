# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoActionSheetCompatibilityTest < Minitest::Test
  def test_cupertino_action_sheet_serializes_current_flet_props
    save = Ruflet.cupertino_action_sheet_action(content: Ruflet.text("Save"), default: true)
    delete = Ruflet.cupertino_action_sheet_action(content: "Delete", destructive: true, mouse_cursor: "click", on_click: ->(_event) {})
    cancel = Ruflet.cupertino_action_sheet_action(content: "Cancel")

    sheet = Ruflet.cupertino_action_sheet(
      title: Ruflet.text("Choose"),
      message: "Select an action",
      actions: [save, delete],
      cancel: cancel
    )

    patch = sheet.to_patch

    assert_equal "CupertinoActionSheet", patch["_c"]
    assert_equal "Text", patch["title"]["_c"]
    assert_equal "Select an action", patch["message"]
    assert_equal %w[CupertinoActionSheetAction CupertinoActionSheetAction], patch["actions"].map { |action| action["_c"] }
    assert_equal "Text", patch["actions"].first["content"]["_c"]
    assert_equal true, patch["actions"].first["default"]
    assert_equal "Delete", patch["actions"].last["content"]
    assert_equal true, patch["actions"].last["destructive"]
    assert_equal "click", patch["actions"].last["mouse_cursor"]
    assert_equal true, patch["actions"].last["on_click"]
    assert_equal "CupertinoActionSheetAction", patch["cancel"]["_c"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "CupertinoActionSheet", Ruflet.cupertinoactionsheet(title: "Title").to_patch["_c"]
    assert_equal "CupertinoActionSheetAction", Ruflet.cupertinoactionsheetaction(content: "Save").to_patch["_c"]
  end

  def test_action_sheet_requires_some_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet }
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet(title: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet(message: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet(cancel: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet(actions: [Ruflet.text("Hidden", visible: false)]) }
  end

  def test_action_sheet_action_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet_action }
    assert_raises(ArgumentError) { Ruflet.cupertino_action_sheet_action(content: Ruflet.text("Hidden", visible: false)) }
  end

  def test_action_sheet_action_defaults_match_flet
    action = Ruflet.cupertino_action_sheet_action(content: "Save")

    assert_equal false, action.props["default"]
    assert_equal false, action.props["destructive"]
  end

  def test_action_sheet_action_click_event_dispatches
    observed = []
    action = Ruflet.cupertino_action_sheet_action(content: "Save", on_click: ->(event) { observed << [event.name, event.control.props["content"]] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(action)

    page.dispatch_event(target: action.wire_id, name: "click", data: nil)

    assert_equal [["click", "Save"]], observed
  end
end
