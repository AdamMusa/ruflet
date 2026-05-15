# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoAlertDialogCompatibilityTest < Minitest::Test
  def test_cupertino_alert_dialog_serializes_current_flet_props
    yes = Ruflet.cupertino_dialog_action(content: "Yes", destructive: true, text_style: { weight: "bold" }, on_click: ->(_event) {})
    no = Ruflet.cupertino_dialog_action(content: Ruflet.text("No"), default: true)

    dialog = Ruflet.cupertino_alert_dialog(
      title: Ruflet.text("Delete file?"),
      content: Ruflet.text("This cannot be undone."),
      actions: [yes, no],
      barrier_color: "#112233",
      inset_animation: { duration: 100, curve: "decelerate" },
      modal: true,
      open: true,
      on_dismiss: ->(_event) {}
    )

    patch = dialog.to_patch

    assert_equal "CupertinoAlertDialog", patch["_c"]
    assert_equal "Text", patch["title"]["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "#112233", patch["barrier_color"]
    assert_equal({ "duration" => 100, "curve" => "decelerate" }, patch["inset_animation"])
    assert_equal true, patch["modal"]
    assert_equal true, patch["open"]
    assert_equal true, patch["on_dismiss"]
    assert_equal %w[CupertinoDialogAction CupertinoDialogAction], patch["actions"].map { |action| action["_c"] }
    assert_equal "Yes", patch["actions"].first["content"]
    assert_equal true, patch["actions"].first["destructive"]
    assert_equal({ "weight" => "bold" }, patch["actions"].first["text_style"])
    assert_equal true, patch["actions"].first["on_click"]
    assert_equal "Text", patch["actions"].last["content"]["_c"]
    assert_equal true, patch["actions"].last["default"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "CupertinoAlertDialog", Ruflet.cupertinoalertdialog(title: "Title").to_patch["_c"]
    assert_equal "CupertinoDialogAction", Ruflet.cupertinodialogaction(content: "OK").to_patch["_c"]
  end

  def test_cupertino_alert_dialog_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_alert_dialog }
    assert_raises(ArgumentError) { Ruflet.cupertino_alert_dialog(title: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.cupertino_alert_dialog(content: Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.cupertino_alert_dialog(actions: [Ruflet.text("Hidden", visible: false)]) }
  end

  def test_cupertino_dialog_action_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_dialog_action }
    assert_raises(ArgumentError) { Ruflet.cupertino_dialog_action(content: Ruflet.text("Hidden", visible: false)) }
  end

  def test_defaults_match_flet
    dialog = Ruflet.cupertino_alert_dialog(title: "Title")
    action = Ruflet.cupertino_dialog_action(content: "OK")

    assert_equal [], dialog.props["actions"]
    assert_equal false, dialog.props["modal"]
    assert_equal({ "duration" => 100, "curve" => "decelerate" }, dialog.props["inset_animation"])
    assert_equal false, action.props["default"]
    assert_equal false, action.props["destructive"]
  end

  def test_dialog_and_action_events_dispatch
    observed = []
    action = Ruflet.cupertino_dialog_action(content: "OK", on_click: ->(event) { observed << [event.name, event.control.props["content"]] })
    dialog = Ruflet.cupertino_alert_dialog(title: "Title", actions: [action], on_dismiss: ->(event) { observed << [event.name, event.control.type] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(dialog)

    page.dispatch_event(target: action.wire_id, name: "click", data: nil)
    page.dispatch_event(target: dialog.wire_id, name: "dismiss", data: nil)

    assert_equal [["click", "OK"], ["dismiss", "cupertinoalertdialog"]], observed
  end
end
