# frozen_string_literal: true

require_relative "test_helper"

class RufletKeyboardDismissBehaviorCompatibilityTest < Minitest::Test
  def scrollables
    [
      [Ruflet.list_view([Ruflet.text("One")], keyboard_dismiss_behavior: "onDrag"), "ListView"],
      [Ruflet.grid_view([Ruflet.text("One")], keyboard_dismiss_behavior: "onDrag"), "GridView"],
      [Ruflet.column([Ruflet.text("One")], scroll: "auto", keyboard_dismiss_behavior: "onDrag"), "Column"],
      [Ruflet.row([Ruflet.text("One")], scroll: "auto", keyboard_dismiss_behavior: "onDrag"), "Row"],
      [Ruflet.view(route: "/", controls: [Ruflet.text("One")], keyboard_dismiss_behavior: "onDrag"), "View"],
      [Ruflet.reorderable_list_view([Ruflet.text("One")], keyboard_dismiss_behavior: "onDrag"), "ReorderableListView"]
    ]
  end

  def test_scrollables_serialize_keyboard_dismiss_behavior
    scrollables.each do |control, wire|
      patch = control.to_patch

      assert_equal wire, patch["_c"]
      assert_equal "onDrag", patch["keyboard_dismiss_behavior"], wire
    end
  end

  def test_symbols_and_manual_are_sent_as_given
    assert_equal "on_drag", Ruflet.list_view(keyboard_dismiss_behavior: :on_drag).to_patch["keyboard_dismiss_behavior"]
    assert_equal "manual", Ruflet.column(keyboard_dismiss_behavior: "manual").to_patch["keyboard_dismiss_behavior"]
  end

  def test_keyboard_dismiss_behavior_is_unset_by_default
    [Ruflet.list_view, Ruflet.grid_view, Ruflet.column, Ruflet.row, Ruflet.view, Ruflet.reorderable_list_view].each do |control|
      refute control.to_patch.key?("keyboard_dismiss_behavior"), control.type
    end
  end

  def test_page_level_keyboard_dismiss_behavior_reaches_the_implicit_view
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.scroll = "auto"
    page.keyboard_dismiss_behavior = "onDrag"
    page.add(Ruflet.text_field(label: "Name"))

    views = sent.last[1]["patch"].find { |op| op[2] == "views" }[3]
    assert_equal "onDrag", views.first["keyboard_dismiss_behavior"]
    assert_equal "onDrag", page.keyboard_dismiss_behavior
  end
end
