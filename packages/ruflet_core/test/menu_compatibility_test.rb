# frozen_string_literal: true

require_relative "test_helper"

class RufletMenuCompatibilityTest < Minitest::Test
  def test_menu_bar_accepts_positional_children_and_serializes_current_flet_props
    menu_item = Ruflet.menu_item_button("Open", leading: Ruflet.icon("folder_open"), trailing: Ruflet.icon("keyboard_arrow_right"))
    submenu_button = Ruflet.submenu_button(
      [menu_item],
      content: Ruflet.text("File"),
      leading: Ruflet.icon("menu"),
      trailing: Ruflet.icon("arrow_drop_down"),
      alignment_offset: { x: 1, y: 2 },
      clip_behavior: "antiAlias",
      menu_style: { bgcolor: "#111111" },
      style: { color: "#222222" },
      on_open: ->(_event) {},
      on_close: ->(_event) {},
      on_focus: ->(_event) {},
      on_blur: ->(_event) {},
      on_hover: ->(_event) {}
    )
    menu_bar = Ruflet.menu_bar(
      [submenu_button],
      clip_behavior: "hardEdge",
      style: { alignment: "start" }
    )

    patch = menu_bar.to_patch

    assert_equal "MenuBar", patch["_c"]
    assert_equal [submenu_button], menu_bar.children
    refute menu_bar.props.key?("controls")
    assert_equal "hardEdge", patch["clip_behavior"]
    assert_equal({ "alignment" => "start" }, patch["style"])

    submenu = patch["controls"].first
    assert_equal "SubmenuButton", submenu["_c"]
    assert_equal [menu_item], submenu_button.children
    refute submenu_button.props.key?("controls")
    assert_equal "Text", submenu["content"]["_c"]
    assert_equal "Icon", submenu["leading"]["_c"]
    assert_equal "Icon", submenu["trailing"]["_c"]
    assert_equal({ "x" => 1, "y" => 2 }, submenu["alignment_offset"])
    assert_equal "antiAlias", submenu["clip_behavior"]
    assert_equal({ "bgcolor" => "#111111" }, submenu["menu_style"])
    assert_equal({ "color" => "#222222" }, submenu["style"])
    assert_equal true, submenu["on_open"]
    assert_equal true, submenu["on_close"]
    assert_equal true, submenu["on_focus"]
    assert_equal true, submenu["on_blur"]
    assert_equal true, submenu["on_hover"]

    item = submenu["controls"].first
    assert_equal "MenuItemButton", item["_c"]
    assert_equal "Open", item["content"]
    assert_equal "Icon", item["leading"]["_c"]
    assert_equal "Icon", item["trailing"]["_c"]
  end

  def test_menu_bar_and_submenu_button_accept_children_keyword_and_controls_alias
    first = Ruflet.menu_item_button("One")
    second = Ruflet.menu_item_button("Two")

    menu_with_children = Ruflet.menu_bar(children: [first])
    menu_with_controls_alias = Ruflet.menu_bar(controls: [second])
    submenu_with_children = Ruflet.submenu_button(children: [first], content: "File")
    submenu_with_controls_alias = Ruflet.submenu_button(controls: [second], content: "Edit")

    assert_equal [first], menu_with_children.children
    assert_equal [second], menu_with_controls_alias.children
    assert_equal [first], submenu_with_children.children
    assert_equal [second], submenu_with_controls_alias.children
    refute menu_with_children.props.key?("controls")
    refute menu_with_controls_alias.props.key?("controls")
    refute submenu_with_children.props.key?("controls")
    refute submenu_with_controls_alias.props.key?("controls")
  end

  def test_menu_bar_and_submenu_button_defaults_match_flet
    menu_bar = Ruflet.menu_bar
    submenu_button = Ruflet.submenu_button(content: "File")

    assert_equal [], menu_bar.children
    assert_equal [], submenu_button.children
    assert_equal "none", menu_bar.props["clip_behavior"]
    assert_equal "none", submenu_button.props["clip_behavior"]
  end

  def test_menu_item_button_serializes_current_flet_props
    item = Ruflet.menu_item_button(
      "Save",
      autofocus: true,
      clip_behavior: "antiAlias",
      close_on_click: false,
      focus_on_hover: true,
      leading: Ruflet.icon("save"),
      overflow_axis: "vertical",
      semantic_label: "Save file",
      style: { color: "#ABCDEF" },
      trailing: Ruflet.icon("keyboard_arrow_right"),
      on_blur: ->(_event) {},
      on_click: ->(_event) {},
      on_focus: ->(_event) {},
      on_hover: ->(_event) {}
    )

    patch = item.to_patch

    assert_equal "MenuItemButton", patch["_c"]
    assert_equal "Save", patch["content"]
    assert_equal true, patch["autofocus"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal false, patch["close_on_click"]
    assert_equal true, patch["focus_on_hover"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal "vertical", patch["overflow_axis"]
    assert_equal "Save file", patch["semantic_label"]
    assert_equal({ "color" => "#ABCDEF" }, patch["style"])
    assert_equal "Icon", patch["trailing"]["_c"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_hover"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "MenuBar", Ruflet.menubar([Ruflet.menuitembutton("Open")]).to_patch["_c"]
    assert_equal "MenuItemButton", Ruflet.menuitembutton("Open").to_patch["_c"]
    assert_equal "SubmenuButton", Ruflet.submenubutton([], content: "File").to_patch["_c"]
  end

  def test_menu_item_and_submenu_require_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.menu_item_button }
    assert_raises(ArgumentError) { Ruflet.menu_item_button(Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.submenu_button([]) }
    assert_raises(ArgumentError) { Ruflet.submenu_button([], content: Ruflet.text("Hidden", visible: false)) }
  end

  def test_menu_controls_reject_negative_height_like_flet
    assert_raises(ArgumentError) { Ruflet.menu_item_button("Open", height: -1) }
    assert_raises(ArgumentError) { Ruflet.submenu_button([], content: "File", height: -1) }
  end

  def test_menu_item_click_event_dispatches
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    events = []
    item = Ruflet.menu_item_button("Open", on_click: ->(event) { events << [event.name, event.control.props["content"]] })
    page.add(Ruflet.menu_bar([item]))

    page.dispatch_event(target: item.wire_id, name: "click", data: nil)

    assert_equal [["click", "Open"]], events
  end
end
