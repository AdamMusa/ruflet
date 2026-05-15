# frozen_string_literal: true

require_relative "test_helper"

class RufletPopupMenuCompatibilityTest < Minitest::Test
  def test_popup_menu_button_accepts_positional_items_and_serializes_current_flet_props
    menu = Ruflet.popup_menu_button(
      [
        Ruflet.popup_menu_item("Edit", icon: "edit", checked: true, on_click: ->(_event) {}),
        Ruflet.popup_menu_item(Ruflet.text("Delete"), icon: Ruflet.icon("delete"))
      ],
      bgcolor: "#ABCDEF",
      clip_behavior: "antiAlias",
      content: Ruflet.text("Actions"),
      elevation: 3,
      enable_feedback: true,
      icon: "more_vert",
      icon_color: "#111111",
      icon_size: 24,
      menu_padding: { left: 8 },
      menu_position: "under",
      padding: { right: 12 },
      popup_animation_style: { duration: 120 },
      shadow_color: "#222222",
      shape: { border_radius: 8 },
      size_constraints: { min_width: 160 },
      splash_radius: 20,
      style: { color: "#333333" },
      tooltip: "More",
      on_cancel: ->(_event) {},
      on_open: ->(_event) {},
      on_select: ->(_event) {}
    )

    patch = menu.to_patch

    assert_equal "PopupMenuButton", patch["_c"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal 3, patch["elevation"]
    assert_equal true, patch["enable_feedback"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("more_vert"), patch["icon"]
    assert_equal "#111111", patch["icon_color"]
    assert_equal 24, patch["icon_size"]
    assert_equal({ "left" => 8 }, patch["menu_padding"])
    assert_equal "under", patch["menu_position"]
    assert_equal({ "right" => 12 }, patch["padding"])
    assert_equal({ "duration" => 120 }, patch["popup_animation_style"])
    assert_equal "#222222", patch["shadow_color"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal({ "min_width" => 160 }, patch["size_constraints"])
    assert_equal 20, patch["splash_radius"]
    assert_equal({ "color" => "#333333" }, patch["style"])
    assert_equal "More", patch["tooltip"]
    assert_equal true, patch["on_cancel"]
    assert_equal true, patch["on_open"]
    assert_equal true, patch["on_select"]

    first, second = patch["items"]
    assert_equal "PopupMenuItem", first["_c"]
    assert_equal "Edit", first["content"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("edit"), first["icon"]
    assert_equal true, first["checked"]
    assert_equal true, first["on_click"]
    assert_equal "Text", second["content"]["_c"]
    assert_equal "Icon", second["icon"]["_c"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "PopupMenuButton", Ruflet.popupmenubutton([Ruflet.popupmenuitem("Edit")]).to_patch["_c"]
    assert_equal "PopupMenuItem", Ruflet.popupmenuitem("Edit").to_patch["_c"]
  end

  def test_popup_menu_item_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.popup_menu_item }
    assert_raises(ArgumentError) { Ruflet.popup_menu_item(Ruflet.text("Hidden", visible: false)) }
  end

  def test_popup_menu_rejects_negative_numeric_values_like_flet
    assert_raises(ArgumentError) { Ruflet.popup_menu_item("Edit", height: -1) }

    %i[elevation icon_size splash_radius].each do |prop|
      error = assert_raises(ArgumentError) do
        Ruflet.popup_menu_button([Ruflet.popup_menu_item("Edit")], prop => -1)
      end

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_popup_menu_select_event_exposes_selected_value
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    menu = Ruflet.popup_menu_button([Ruflet.popup_menu_item("Edit")], on_select: ->(event) { observed << event.value })
    page.add(menu)

    page.dispatch_event(target: menu.wire_id, name: "select", data: { "value" => "edit" })

    assert_equal ["edit"], observed
  end
end
