# frozen_string_literal: true

require_relative "test_helper"

class RufletDragAndDropCompatibilityTest < Minitest::Test
  def test_draggable_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.draggable(
      Ruflet.container(bgcolor: "#00ffff"),
      affinity: "horizontal",
      axis: "vertical",
      content_feedback: Ruflet.container(bgcolor: "#00ffff", opacity: 0.5),
      content_when_dragging: Ruflet.container(width: 50),
      group: "colors",
      max_simultaneous_drags: 1,
      on_drag_complete: ->(_event) {},
      on_drag_start: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "Draggable", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal "horizontal", patch["affinity"]
    assert_equal "vertical", patch["axis"]
    assert_equal "Container", patch["content_feedback"]["_c"]
    assert_equal "Container", patch["content_when_dragging"]["_c"]
    assert_equal "colors", patch["group"]
    assert_equal 1, patch["max_simultaneous_drags"]
    assert_equal true, patch["on_drag_complete"]
    assert_equal true, patch["on_drag_start"]
  end

  def test_drag_target_accepts_positional_content_and_serializes_current_flet_props
    target = Ruflet.drag_target(
      Ruflet.container(bgcolor: "#eeeeee"),
      group: "colors",
      on_accept: ->(_event) {},
      on_leave: ->(_event) {},
      on_move: ->(_event) {},
      on_will_accept: ->(_event) {}
    )

    patch = target.to_patch

    assert_equal "DragTarget", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal "colors", patch["group"]
    assert_equal true, patch["on_accept"]
    assert_equal true, patch["on_leave"]
    assert_equal true, patch["on_move"]
    assert_equal true, patch["on_will_accept"]
  end

  def test_drag_and_drop_defaults_match_flet
    draggable = Ruflet.draggable(Ruflet.text("Drag"))
    target = Ruflet.drag_target(Ruflet.text("Drop"))

    assert_equal "default", draggable.props["group"]
    assert_equal "default", target.props["group"]
  end

  def test_drag_and_drop_require_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.draggable }
    assert_raises(ArgumentError) { Ruflet.draggable(Ruflet.text("Hidden", visible: false)) }
    assert_raises(ArgumentError) { Ruflet.drag_target }
    assert_raises(ArgumentError) { Ruflet.drag_target(Ruflet.text("Hidden", visible: false)) }
  end

  def test_draggable_rejects_negative_max_simultaneous_drags_like_flet
    assert_raises(ArgumentError) { Ruflet.draggable(Ruflet.text("Drag"), max_simultaneous_drags: -1) }
  end

  def test_drag_target_events_expose_source_and_acceptance_details
    events = []
    target = Ruflet.drag_target(
      Ruflet.text("Drop"),
      on_will_accept: ->(event) { events << [event.name, event.src_id, event.accept] },
      on_accept: ->(event) { events << [event.name, event.src_id] },
      on_move: ->(event) { events << [event.name, event.src_id, event.x, event.y] },
      on_leave: ->(event) { events << [event.name, event.src_id] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(target)

    page.dispatch_event(target: target.wire_id, name: "will_accept", data: { "src_id" => "drag1", "accept" => true })
    page.dispatch_event(target: target.wire_id, name: "accept", data: { "src_id" => "drag1" })
    page.dispatch_event(target: target.wire_id, name: "move", data: { "src_id" => "drag1", "x" => 4, "y" => 8 })
    page.dispatch_event(target: target.wire_id, name: "leave", data: { "src_id" => "drag1" })

    assert_equal [
      ["will_accept", "drag1", true],
      ["accept", "drag1"],
      ["move", "drag1", 4, 8],
      ["leave", "drag1"]
    ], events
  end
end
