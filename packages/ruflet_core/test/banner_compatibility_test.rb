# frozen_string_literal: true

require_relative "test_helper"

class RufletBannerCompatibilityTest < Minitest::Test
  def test_banner_accepts_positional_content_and_serializes_current_flet_props
    banner = Ruflet.banner(
      Ruflet.text("Backup completed."),
      actions: [Ruflet.text_button(content: Ruflet.text("Dismiss"))],
      bgcolor: "#ABCDEF",
      content_padding: { left: 16, top: 24 },
      content_text_style: { size: 14 },
      divider_color: "#111111",
      elevation: 4,
      force_actions_below: true,
      leading: Ruflet.icon("info"),
      leading_padding: 16,
      margin: { top: 8 },
      min_action_bar_height: 52,
      open: true,
      shadow_color: "#222222",
      surface_tint_color: "#333333",
      on_dismiss: ->(_event) {},
      on_visible: ->(_event) {}
    )

    patch = banner.to_patch

    assert_equal "Banner", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "Backup completed.", patch["content"]["value"]
    assert_equal ["TextButton"], patch["actions"].map { |action| action["_c"] }
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "left" => 16, "top" => 24 }, patch["content_padding"])
    assert_equal({ "size" => 14 }, patch["content_text_style"])
    assert_equal "#111111", patch["divider_color"]
    assert_equal 4, patch["elevation"]
    assert_equal true, patch["force_actions_below"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal 16, patch["leading_padding"]
    assert_equal({ "top" => 8 }, patch["margin"])
    assert_equal 52, patch["min_action_bar_height"]
    assert_equal true, patch["open"]
    assert_equal "#222222", patch["shadow_color"]
    assert_equal "#333333", patch["surface_tint_color"]
    assert_equal true, patch["on_dismiss"]
    assert_equal true, patch["on_visible"]
  end

  def test_banner_requires_content_like_flet
    assert_match(/content/, assert_raises(ArgumentError) { Ruflet.banner(actions: [Ruflet.text_button(content: "OK")]) }.message)
  end

  def test_banner_serializes_empty_actions_and_negative_numeric_values_like_flet
    patch = Ruflet.banner("Hello", actions: [], elevation: -1, min_action_bar_height: -2).to_patch

    assert_equal [], patch["actions"]
    assert_equal(-1, patch["elevation"])
    assert_equal(-2, patch["min_action_bar_height"])
  end

  def test_banner_visible_and_dismiss_events_dispatch
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    banner = Ruflet.banner(
      "Hello",
      actions: [Ruflet.text_button(content: "OK")],
      on_visible: ->(event) { events << event.name },
      on_dismiss: ->(event) { events << event.name }
    )

    page.add(Ruflet.text("Root"))
    page.show_dialog(banner)
    page.dispatch_event(target: banner.wire_id, name: "visible", data: nil)
    page.dispatch_event(target: banner.wire_id, name: "dismiss", data: nil)

    assert_equal ["visible", "dismiss"], events
  end

  def test_page_show_and_close_banner_helpers_target_the_given_banner
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    banner = Ruflet.banner("Saved", actions: [Ruflet.text_button(content: "Dismiss")])

    page.add(Ruflet.text("Root"))
    page.show_banner(banner)
    assert_equal true, banner.props["open"]

    assert_same banner, page.close_banner(banner)
    assert_equal false, banner.props["open"]
    # Closing must patch `open` on the mounted control itself; replacing the
    # dialogs container recreates the control client-side and the close
    # transition is lost (alert_dialog.dart tracks open/_open per instance).
    last_action, last_payload = sent.last
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], last_action
    assert_equal banner.wire_id, last_payload["id"]
    assert_includes last_payload["patch"], [0, 0, "open", false]
  end
end
