# frozen_string_literal: true

require_relative "test_helper"

class RufletSnackBarCompatibilityTest < Minitest::Test
  def test_snack_bar_accepts_positional_content_and_serializes_current_flet_props
    snack_bar = Ruflet.snack_bar(
      Ruflet.text("Saved"),
      action: "Undo",
      action_overflow_threshold: 0.5,
      behavior: "floating",
      bgcolor: "#ABCDEF",
      clip_behavior: "hardEdge",
      close_icon_color: "#123456",
      dismiss_direction: "down",
      duration: 4000,
      elevation: 6,
      margin: { left: 8, right: 8 },
      open: true,
      padding: 12,
      persist: true,
      shape: { border_radius: 8 },
      show_close_icon: true,
      width: 320,
      on_action: ->(_event) {},
      on_visible: ->(_event) {}
    )

    patch = snack_bar.to_patch

    assert_equal "SnackBar", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "Saved", patch["content"]["value"]
    assert_equal "Undo", patch["action"]
    assert_equal 0.5, patch["action_overflow_threshold"]
    assert_equal "floating", patch["behavior"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "hardEdge", patch["clip_behavior"]
    assert_equal "#123456", patch["close_icon_color"]
    assert_equal "down", patch["dismiss_direction"]
    assert_equal 4000, patch["duration"]
    assert_equal 6, patch["elevation"]
    assert_equal({ "left" => 8, "right" => 8 }, patch["margin"])
    assert_equal true, patch["open"]
    assert_equal 12, patch["padding"]
    assert_equal true, patch["persist"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal true, patch["show_close_icon"]
    assert_equal 320, patch["width"]
    assert_equal true, patch["on_action"]
    assert_equal true, patch["on_visible"]
  end

  def test_snack_bar_requires_content_like_flet
    error = assert_raises(ArgumentError) { Ruflet.snack_bar }

    assert_match(/content/, error.message)
  end

  def test_snack_bar_action_serializes_current_flet_props
    action = Ruflet.snack_bar_action(
      "Undo",
      text_color: "#ABCDEF",
      disabled_text_color: "#123456",
      bgcolor: "#FEDCBA",
      disabled_bgcolor: "#654321",
      on_click: ->(_event) {}
    )
    patch = action.to_patch

    assert_equal "SnackBarAction", patch["_c"]
    assert_equal "Undo", patch["label"]
    assert_equal "#abcdef", patch["text_color"]
    assert_equal "#123456", patch["disabled_text_color"]
    assert_equal "#fedcba", patch["bgcolor"]
    assert_equal "#654321", patch["disabled_bgcolor"]
    assert_equal true, patch["on_click"]
    assert_equal "SnackBarAction", Ruflet.snackbaraction("Undo").to_patch["_c"]
  end

  def test_snack_bar_action_requires_label_like_flet
    assert_raises(ArgumentError) { Ruflet.snack_bar_action }
  end

  def test_snack_bar_accepts_action_control_like_flet
    patch = Ruflet.snack_bar("Saved", action: Ruflet.snack_bar_action("Undo")).to_patch

    assert_equal "SnackBarAction", patch["action"]["_c"]
    assert_equal "Undo", patch["action"]["label"]
  end

  def test_snack_bar_serializes_action_overflow_threshold_outside_flet_range
    low = Ruflet.snack_bar("Saved", action_overflow_threshold: -0.1)
    high = Ruflet.snack_bar("Saved", action_overflow_threshold: 1.1)

    assert_equal(-0.1, low.to_patch["action_overflow_threshold"])
    assert_equal 1.1, high.to_patch["action_overflow_threshold"]
  end

  def test_snack_bar_action_and_visible_events_dispatch
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    snack_bar = Ruflet.snack_bar(
      "Saved",
      on_action: ->(event) { events << event.name },
      on_visible: ->(event) { events << event.name }
    )

    page.add(Ruflet.text("Root"))
    page.show_snackbar(snack_bar)
    page.dispatch_event(target: snack_bar.wire_id, name: "visible", data: nil)
    page.dispatch_event(target: snack_bar.wire_id, name: "action", data: nil)

    assert_equal ["visible", "action"], events
  end
end
