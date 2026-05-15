# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoContextMenuCompatibilityTest < Minitest::Test
  def test_cupertino_context_menu_serializes_current_flet_props
    action = Ruflet.cupertino_context_menu_action(
      content: "Copy",
      default: true,
      destructive: false,
      trailing_icon: "content_copy",
      on_click: ->(_event) {}
    )

    menu = Ruflet.cupertino_context_menu(
      content: Ruflet.image("photo.png"),
      actions: [action],
      enable_haptic_feedback: false
    )

    patch = menu.to_patch

    assert_equal "CupertinoContextMenu", patch["_c"]
    assert_equal "Image", patch["content"]["_c"]
    assert_equal false, patch["enable_haptic_feedback"]
    assert_equal ["CupertinoContextMenuAction"], patch["actions"].map { |item| item["_c"] }
    assert_equal "Copy", patch["actions"].first["content"]
    assert_equal true, patch["actions"].first["default"]
    assert_equal false, patch["actions"].first["destructive"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("content_copy"), patch["actions"].first["trailing_icon"]
    assert_equal true, patch["actions"].first["on_click"]
  end

  def test_compact_aliases_use_same_controls
    action = Ruflet.cupertinocontextmenuaction(content: "Copy")

    assert_equal "CupertinoContextMenuAction", action.to_patch["_c"]
    assert_equal "CupertinoContextMenu", Ruflet.cupertinocontextmenu(content: Ruflet.text("Photo"), actions: [action]).to_patch["_c"]
  end

  def test_context_menu_requires_visible_content_and_actions_like_flet
    action = Ruflet.cupertino_context_menu_action(content: "Copy")

    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu(actions: [action]) }
    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu(content: Ruflet.text("Hidden", visible: false), actions: [action]) }
    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu(content: Ruflet.text("Photo")) }
    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu(content: Ruflet.text("Photo"), actions: [Ruflet.text("Hidden", visible: false)]) }
  end

  def test_context_menu_action_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu_action }
    assert_raises(ArgumentError) { Ruflet.cupertino_context_menu_action(content: Ruflet.text("Hidden", visible: false)) }
  end

  def test_defaults_match_flet
    action = Ruflet.cupertino_context_menu_action(content: "Copy")
    menu = Ruflet.cupertino_context_menu(content: Ruflet.text("Photo"), actions: [action])

    assert_equal true, menu.props["enable_haptic_feedback"]
    assert_equal false, action.props["default"]
    assert_equal false, action.props["destructive"]
  end

  def test_context_menu_action_click_event_dispatches
    observed = []
    action = Ruflet.cupertino_context_menu_action(content: "Copy", on_click: ->(event) { observed << [event.name, event.control.props["content"]] })
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(action)

    page.dispatch_event(target: action.wire_id, name: "click", data: nil)

    assert_equal [["click", "Copy"]], observed
  end
end
