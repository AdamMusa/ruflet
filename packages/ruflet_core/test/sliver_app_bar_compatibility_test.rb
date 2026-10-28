# frozen_string_literal: true

require_relative "test_helper"

class RufletSliverAppBarCompatibilityTest < Minitest::Test
  def test_sliver_app_bar_serializes_material_and_cupertino_props
    bar = Ruflet.sliver_app_bar(
      title: "Inbox",
      variant: "large",
      leading: Ruflet.text("Back"),
      actions: [Ruflet.text("Edit"), Ruflet.text("Add")],
      pinned: true,
      floating: true,
      snap: true,
      stretch: true,
      expanded_height: 220,
      collapsed_height: 72,
      toolbar_height: 64,
      flexible_space: Ruflet.container(bgcolor: "#123456"),
      bottom: Ruflet.text("Tabs"),
      bottom_height: 40,
      bgcolor: "#ABCDEF",
      color: "#FFFFFF",
      elevation: 2,
      scrolled_under_elevation: 4,
      shadow_color: "#000000",
      center_title: true,
      automatically_imply_leading: false,
      previous_page_title: "Mailboxes",
      border: { bottom: { width: 0.5 } },
      always_show_middle: false,
      transition_between_routes: true,
      key: "inbox-bar"
    )

    patch = bar.to_patch

    assert_equal "SliverAppBar", patch["_c"]
    assert_equal "Inbox", patch["title"]
    assert_equal "large", patch["variant"]
    assert_equal "Back", patch["leading"]["value"]
    assert_equal %w[Edit Add], patch["actions"].map { |action| action["value"] }
    assert_equal true, patch["pinned"]
    assert_equal true, patch["floating"]
    assert_equal true, patch["snap"]
    assert_equal true, patch["stretch"]
    assert_equal 220, patch["expanded_height"]
    assert_equal 72, patch["collapsed_height"]
    assert_equal 64, patch["toolbar_height"]
    assert_equal "Container", patch["flexible_space"]["_c"]
    assert_equal "Tabs", patch["bottom"]["value"]
    assert_equal 40, patch["bottom_height"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#ffffff", patch["color"]
    assert_equal 2, patch["elevation"]
    assert_equal 4, patch["scrolled_under_elevation"]
    assert_equal "#000000", patch["shadow_color"]
    assert_equal true, patch["center_title"]
    assert_equal false, patch["automatically_imply_leading"]
    assert_equal "Mailboxes", patch["previous_page_title"]
    assert_equal({ "bottom" => { "width" => 0.5 } }, patch["border"])
    assert_equal false, patch["always_show_middle"]
    assert_equal true, patch["transition_between_routes"]
    assert_equal "inbox-bar", patch["key"]
  end

  def test_sliver_app_bar_defaults
    bar = Ruflet.sliver_app_bar(title: Ruflet.text("Settings"))

    assert_equal "sliverappbar", bar.type
    assert_equal "Text", bar.to_patch["title"]["_c"]
    assert_equal "small", bar.props["variant"]
    # nil: Dart pins medium/large and leaves small unpinned.
    refute bar.props.key?("pinned")
    assert_equal false, bar.props["floating"]
    assert_equal false, bar.props["snap"]
    assert_equal false, bar.props["stretch"]
    assert_equal true, bar.props["automatically_imply_leading"]
    assert_equal true, bar.props["always_show_middle"]
    # Off by default: avoids duplicate navigation-bar heroes on iOS.
    assert_equal false, bar.props["transition_between_routes"]
  end

  def test_compact_alias_and_generic_control_use_same_control
    assert_equal "SliverAppBar", Ruflet.sliverappbar(title: "A").to_patch["_c"]
    assert_equal "SliverAppBar", Ruflet.control(:sliver_app_bar, title: "A").to_patch["_c"]
  end

  def test_sliver_app_bar_is_a_sliver_child_without_box_layout_or_events
    assert_raises(ArgumentError) { Ruflet.sliver_app_bar(width: 100) }
    assert_raises(ArgumentError) { Ruflet.sliver_app_bar(expand: true) }
    assert_raises(ArgumentError) { Ruflet.sliver_app_bar(on_click: ->(_e) {}) }
  end

  def test_sliver_app_bar_goes_first_in_a_custom_scroll_view
    view = Ruflet.custom_scroll_view(
      [
        Ruflet.sliver_app_bar(title: "Inbox", variant: "large", actions: [Ruflet.icon_button(icon: "search")]),
        Ruflet.sliver_list([Ruflet.text("Message")])
      ],
      expand: true
    )

    slivers = view.to_patch["slivers"]
    assert_equal %w[SliverAppBar SliverList], slivers.map { |sliver| sliver["_c"] }
    assert_equal "IconButton", slivers.first["actions"].first["_c"]
  end

  def test_actions_and_title_patch_through_the_page
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    bar = Ruflet.sliver_app_bar(title: "Inbox", variant: "large")
    page.add(Ruflet.custom_scroll_view([bar], expand: true))

    messages.clear
    page.update(bar, title: "Archive")

    _action, payload = messages.last
    assert_equal bar.wire_id, payload["id"]
    assert_includes payload.inspect, "Archive"
  end
end
