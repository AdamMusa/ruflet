# frozen_string_literal: true

require_relative "test_helper"

class RufletReorderableListViewCompatibilityTest < Minitest::Test
  def test_reorderable_list_view_accepts_positional_children_and_serializes_current_flet_props
    list = Ruflet.reorderable_list_view(
      [
        Ruflet.text("One"),
        Ruflet.reorderable_drag_handle(Ruflet.icon("drag_handle"))
      ],
      horizontal: false,
      spacing: 8,
      padding: { left: 4 },
      auto_scroll: true,
      show_default_drag_handles: false,
      on_reorder: ->(_event) {}
    )

    patch = list.to_patch

    assert_equal "ReorderableListView", patch["_c"]
    assert_equal ["text", "reorderabledraghandle"], list.children.map(&:type)
    refute list.props.key?("controls")
    assert_equal false, patch["horizontal"]
    assert_equal 8, patch["spacing"]
    assert_equal({ "left" => 4 }, patch["padding"])
    assert_equal true, patch["auto_scroll"]
    assert_equal false, patch["show_default_drag_handles"]
    assert_equal true, patch["on_reorder"]
    assert_equal "Text", patch["controls"].first["_c"]
    assert_equal "ReorderableDragHandle", patch["controls"].last["_c"]
  end

  def test_reorderable_list_view_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.text("One")
    second = Ruflet.text("Two")

    with_children = Ruflet.reorderable_list_view(children: [first])
    with_controls_alias = Ruflet.reorderable_list_view(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_compact_aliases_use_same_controls
    list = Ruflet.reorderablelistview([Ruflet.text("One")])
    handle = Ruflet.reorderabledraghandle(Ruflet.icon("drag_handle"))

    assert_equal "reorderablelistview", list.type
    assert_equal "ReorderableListView", list.to_patch["_c"]
    assert_equal "reorderabledraghandle", handle.type
    assert_equal "ReorderableDragHandle", handle.to_patch["_c"]
  end

  def test_reorderable_drag_handle_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.reorderable_drag_handle }
    assert_raises(ArgumentError) { Ruflet.reorderable_drag_handle(Ruflet.icon("drag_handle", visible: false)) }

    handle = Ruflet.reorderable_drag_handle(Ruflet.icon("drag_handle"))
    assert_equal "icon", handle.props["content"].type
  end

  def test_reorder_event_exposes_old_and_new_indexes
    observed = nil
    list = Ruflet.reorderable_list_view(
      [Ruflet.text("One"), Ruflet.text("Two")],
      on_reorder: ->(event) { observed = [event.old_index, event.new_index, event.value] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(list)

    page.dispatch_event(target: list.wire_id, name: "reorder", data: { "old_index" => 0, "new_index" => 1 })

    assert_equal [0, 1, [0, 1]], observed
  end
end
