# frozen_string_literal: true

require_relative "test_helper"

class RufletWindowDragAreaCompatibilityTest < Minitest::Test
  def test_window_drag_area_accepts_positional_content_and_serializes_current_flet_props
    area = Ruflet.window_drag_area(
      Ruflet.container(content: Ruflet.text("Drag me")),
      maximizable: false,
      expand: true,
      on_double_tap: ->(_event) {},
      on_drag_start: ->(_event) {},
      on_drag_end: ->(_event) {}
    )

    patch = area.to_patch

    assert_equal "WindowDragArea", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal false, patch["maximizable"]
    assert_equal true, patch["expand"]
    assert_equal true, patch["on_double_tap"]
    assert_equal true, patch["on_drag_start"]
    assert_equal true, patch["on_drag_end"]
  end

  def test_compact_alias_uses_same_control
    area = Ruflet.windowdragarea(Ruflet.text("Drag me"))

    assert_equal "windowdragarea", area.type
    assert_equal "WindowDragArea", area.to_patch["_c"]
  end

  def test_window_drag_area_defaults_match_flet
    area = Ruflet.window_drag_area(Ruflet.text("Drag me"))

    assert_equal true, area.props["maximizable"]
  end

  def test_window_drag_area_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.window_drag_area }
    assert_raises(ArgumentError) { Ruflet.window_drag_area(Ruflet.text("Hidden", visible: false)) }

    area = Ruflet.window_drag_area(Ruflet.text("Shown"))
    assert_equal "Shown", area.props["content"].props["value"]
  end

  def test_drag_and_double_tap_events_dispatch
    events = []
    area = Ruflet.window_drag_area(
      Ruflet.text("Drag me"),
      on_double_tap: ->(event) { events << [event.name, event.value] },
      on_drag_start: ->(event) { events << [event.name, event.control.type] },
      on_drag_end: ->(event) { events << [event.name, event.control.type] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(area)

    page.dispatch_event(target: area.wire_id, name: "double_tap", data: { "value" => "maximize" })
    page.dispatch_event(target: area.wire_id, name: "drag_start", data: {})
    page.dispatch_event(target: area.wire_id, name: "drag_end", data: {})

    assert_equal [["double_tap", "maximize"], ["drag_start", "windowdragarea"], ["drag_end", "windowdragarea"]], events
  end
end
