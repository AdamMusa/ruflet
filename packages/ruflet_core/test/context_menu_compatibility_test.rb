# frozen_string_literal: true

require_relative "test_helper"

class RufletContextMenuCompatibilityTest < Minitest::Test
  def test_context_menu_accepts_positional_content_and_serializes_current_flet_props
    menu = Ruflet.context_menu(
      Ruflet.container(content: Ruflet.text("Open menu"), bgcolor: "#ABCDEF"),
      items: [
        Ruflet.popup_menu_item("Programmatic")
      ],
      primary_items: [
        Ruflet.popup_menu_item("Primary", icon: "touch_app")
      ],
      primary_trigger: "down",
      secondary_items: [
        Ruflet.popup_menu_item(Ruflet.text("Secondary"), icon: Ruflet.icon("mouse"))
      ],
      secondary_trigger: "down",
      tertiary_items: [
        Ruflet.popup_menu_item("Tertiary")
      ],
      tertiary_trigger: "down",
      on_dismiss: ->(_event) {},
      on_select: ->(_event) {}
    )

    patch = menu.to_patch

    assert_equal "ContextMenu", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal "PopupMenuItem", patch["items"].first["_c"]
    assert_equal "Programmatic", patch["items"].first["content"]
    assert_equal "PopupMenuItem", patch["primary_items"].first["_c"]
    assert_equal "Primary", patch["primary_items"].first["content"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("touch_app"), patch["primary_items"].first["icon"]
    assert_equal "down", patch["primary_trigger"]
    assert_equal "PopupMenuItem", patch["secondary_items"].first["_c"]
    assert_equal "Text", patch["secondary_items"].first["content"]["_c"]
    assert_equal "Icon", patch["secondary_items"].first["icon"]["_c"]
    assert_equal "down", patch["secondary_trigger"]
    assert_equal "PopupMenuItem", patch["tertiary_items"].first["_c"]
    assert_equal "Tertiary", patch["tertiary_items"].first["content"]
    assert_equal "down", patch["tertiary_trigger"]
    assert_equal true, patch["on_dismiss"]
    assert_equal true, patch["on_select"]
  end

  def test_contextmenu_alias_uses_same_control
    menu = Ruflet.contextmenu(Ruflet.text("Target"), items: [Ruflet.popup_menu_item("Open")])

    assert_equal "ContextMenu", menu.to_patch["_c"]
  end

  def test_context_menu_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.context_menu }
    assert_raises(ArgumentError) { Ruflet.context_menu(Ruflet.text("Hidden", visible: false)) }
  end

  def test_context_menu_select_and_dismiss_events_dispatch
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    menu = Ruflet.context_menu(
      Ruflet.text("Target"),
      items: [Ruflet.popup_menu_item("Open")],
      on_select: ->(event) { events << [:select, event.value] },
      on_dismiss: ->(event) { events << [event.name, event.raw_data] }
    )
    page.add(menu)

    page.dispatch_event(target: menu.wire_id, name: "select", data: { "value" => "Open" })
    page.dispatch_event(target: menu.wire_id, name: "dismiss", data: { "item_count" => 1, "trigger" => "primary" })

    assert_equal [[:select, "Open"], ["dismiss", { "item_count" => 1, "trigger" => "primary" }]], events
  end

  def test_context_menu_open_invokes_flet_control_method
    messages = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { messages << [action, payload] }
    )
    menu = Ruflet.context_menu(Ruflet.text("Target"), items: [Ruflet.popup_menu_item("Open")])
    page.add(menu)
    messages.clear

    menu.open(position: { x: 10, y: 20 })

    assert_equal ["open"], messages.map { |_action, payload| payload["name"] }
    assert_equal({ "position" => { "x" => 10, "y" => 20 } }, messages.first.last["args"])
  end
end
