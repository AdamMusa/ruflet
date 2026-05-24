# frozen_string_literal: true

require_relative "test_helper"

class RufletAlertDialogCompatibilityTest < Minitest::Test
  def test_alert_dialog_serializes_current_flet_props_with_snake_case_keys
    dialog = Ruflet.alert_dialog(
      title: Ruflet.text("Session expired"),
      content: Ruflet.text("Please sign in again."),
      actions: [Ruflet.text_button(content: Ruflet.text("Dismiss"))],
      action_button_padding: 8,
      actions_alignment: "end",
      actions_overflow_button_spacing: 4,
      actions_padding: { left: 12, right: 12 },
      alignment: { x: 0, y: 0 },
      barrier_color: "#ABCDEF",
      bgcolor: "#123456",
      clip_behavior: "antiAlias",
      content_padding: 16,
      content_text_style: { size: 12 },
      elevation: 6,
      icon: Ruflet.icon("info"),
      icon_color: "#654321",
      icon_padding: 10,
      inset_padding: { vertical: 40, horizontal: 24 },
      modal: true,
      open: true,
      scrollable: true,
      semantics_label: "Expired session dialog",
      shadow_color: "#222222",
      shape: { border_radius: 8 },
      title_padding: 20,
      title_text_style: { weight: "bold" }
    )

    patch = dialog.to_patch

    assert_equal "AlertDialog", patch["_c"]
    assert_equal "Text", patch["title"]["_c"]
    assert_equal "Session expired", patch["title"]["value"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal ["TextButton"], patch["actions"].map { |action| action["_c"] }
    assert_equal 8, patch["action_button_padding"]
    assert_equal "end", patch["actions_alignment"]
    assert_equal 4, patch["actions_overflow_button_spacing"]
    assert_equal({ "left" => 12, "right" => 12 }, patch["actions_padding"])
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal "#abcdef", patch["barrier_color"]
    assert_equal "#123456", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 16, patch["content_padding"]
    assert_equal({ "size" => 12 }, patch["content_text_style"])
    assert_equal 6, patch["elevation"]
    assert_equal "Icon", patch["icon"]["_c"]
    assert_equal "#654321", patch["icon_color"]
    assert_equal 10, patch["icon_padding"]
    assert_equal({ "vertical" => 40, "horizontal" => 24 }, patch["inset_padding"])
    assert_equal true, patch["modal"]
    assert_equal true, patch["open"]
    assert_equal true, patch["scrollable"]
    assert_equal "Expired session dialog", patch["semantics_label"]
    assert_equal "#222222", patch["shadow_color"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal 20, patch["title_padding"]
    assert_equal({ "weight" => "bold" }, patch["title_text_style"])
  end

  def test_alert_dialog_requires_title_content_or_actions_like_flet
    error = assert_raises(ArgumentError) { Ruflet.alert_dialog }

    assert_match(/title, content, or actions/, error.message)
  end

  def test_alert_dialog_dismiss_event_closes_dialog_tracking_and_calls_handler
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    dismissed = []
    dialog = Ruflet.alert_dialog(
      title: Ruflet.text("Hello"),
      on_dismiss: ->(event) { dismissed << [event.name, event.control.props["open"]] }
    )

    page.add(Ruflet.text("Root"))
    page.show_dialog(dialog)
    page.dispatch_event(target: dialog.wire_id, name: "dismiss", data: nil)

    assert_equal [["dismiss", true]], dismissed
    assert_equal [], sent.last[1]["patch"][1][3]
  end

  def test_page_update_close_untracks_dialog_like_flet_close
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    dialog = Ruflet.alert_dialog(title: Ruflet.text("Hello"))
    page.add(Ruflet.text("Root"))
    page.show_dialog(dialog)
    sent.clear

    page.update(dialog, open: false)

    assert_equal false, dialog.props["open"]
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], sent[-2][0]
    assert_equal dialog.wire_id, sent[-2][1]["id"]
    assert_includes sent[-2][1]["patch"], [0, 0, "open", false]
    controls_patch = sent[-1][1]["patch"].find { |op| op[2] == "controls" }
    assert_equal [], controls_patch[3]

    sent.clear
    page.dispatch_event(target: dialog.wire_id, name: "dismiss", data: nil)
    assert_empty sent

    page.show_dialog(dialog)

    controls_patch = sent.last[1]["patch"].find { |op| op[2] == "controls" }
    assert_equal true, controls_patch[3].first["open"]
  end

  def test_pop_dialog_closes_and_removes_latest_dialog_from_container
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    dialog = Ruflet.alert_dialog(title: Ruflet.text("Hello"))
    page.add(Ruflet.text("Root"))
    page.show_dialog(dialog)
    sent.clear

    popped = page.pop_dialog

    assert_same dialog, popped
    assert_equal false, dialog.props["open"]
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], sent[-2][0]
    closing_patch = sent[-2][1]["patch"].find { |op| op[2] == "open" }
    removed_controls = sent[-1][1]["patch"].find { |op| op[2] == "controls" }[3]
    assert_equal dialog.wire_id, sent[-2][1]["id"]
    assert_equal false, closing_patch[3]
    assert_equal [], removed_controls
  end

  def test_initial_page_patch_mounts_dialogs_before_views_like_flet
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text("Root"))

    patch_keys = sent.last[1]["patch"].drop(1).map { |op| op[2] }

    refute_nil patch_keys.index("_dialogs")
    refute_nil patch_keys.index("_overlay")
    assert_operator patch_keys.index("_dialogs"), :<, patch_keys.index("views")
  end
end
