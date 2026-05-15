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

  def test_banner_requires_content_and_actions_like_flet
    assert_match(/content/, assert_raises(ArgumentError) { Ruflet.banner(actions: [Ruflet.text_button(content: "OK")]) }.message)
    assert_match(/actions/, assert_raises(ArgumentError) { Ruflet.banner("Hello") }.message)
  end

  def test_banner_rejects_negative_numeric_values_like_flet
    %i[elevation min_action_bar_height].each do |prop|
      error = assert_raises(ArgumentError) do
        Ruflet.banner("Hello", actions: [Ruflet.text_button(content: "OK")], prop => -1)
      end

      assert_match(/#{prop}/, error.message)
    end
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
end
