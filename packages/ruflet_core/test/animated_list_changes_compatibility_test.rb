# frozen_string_literal: true

require_relative "test_helper"

class RufletAnimatedListChangesCompatibilityTest < Minitest::Test
  ITEM_ANIMATION = { type: "slide", duration: 300, curve: "easeOut" }.freeze

  def test_list_view_and_column_serialize_animation_keywords
    [
      [Ruflet.list_view([Ruflet.text("One")], animate_changes: true, item_animation: ITEM_ANIMATION), "ListView"],
      [Ruflet.column([Ruflet.text("One")], animate_changes: true, item_animation: ITEM_ANIMATION), "Column"]
    ].each do |control, wire|
      patch = control.to_patch

      assert_equal wire, patch["_c"]
      assert_equal true, patch["animate_changes"], wire
      assert_equal({ "type" => "slide", "duration" => 300, "curve" => "easeOut" }, patch["item_animation"], wire)
    end
  end

  def test_animation_is_off_by_default
    [Ruflet.list_view, Ruflet.column].each do |control|
      refute control.to_patch.key?("animate_changes"), control.type
      refute control.to_patch.key?("item_animation"), control.type
    end
  end

  def test_other_scrollables_reject_animate_changes
    assert_raises(ArgumentError) { Ruflet.grid_view(animate_changes: true) }
    assert_raises(ArgumentError) { Ruflet.row(animate_changes: true) }
  end

  def test_removing_a_child_sends_the_new_children_with_stable_ids
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    todos = Ruflet.list_view((1..4).map { |i| Ruflet.text("Todo #{i}") }, animate_changes: true)
    page.add(todos)
    ids_before = todos.children.map(&:wire_id)
    sent.clear

    todos.children.delete_at(1)
    page.update

    patch = sent.find { |action, payload| action == Ruflet::Protocol::ACTIONS[:patch_control] && payload["id"] == todos.wire_id }
    refute_nil patch
    controls = patch[1]["patch"].find { |op| op[2] == "controls" }[3]
    assert_equal ids_before.values_at(0, 2, 3), controls.map { |control| control["_i"] },
                 "the renderer diffs children by their stable wire ids"
  end
end
