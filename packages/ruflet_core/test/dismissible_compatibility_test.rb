# frozen_string_literal: true

require_relative "test_helper"

class RufletDismissibleCompatibilityTest < Minitest::Test
  def test_dismissible_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.dismissible(
      Ruflet.list_tile(title: Ruflet.text("Item")),
      background: Ruflet.container(bgcolor: "#00ff00"),
      secondary_background: Ruflet.container(bgcolor: "#ff0000"),
      cross_axis_end_offset: 0.2,
      dismiss_direction: "endToStart",
      dismiss_thresholds: { end_to_start: 0.4 },
      movement_duration: 150,
      resize_duration: 250,
      on_confirm_dismiss: ->(_event) {},
      on_dismiss: ->(_event) {},
      on_update: ->(_event) {}
    )

    patch = control.to_patch

    assert_equal "Dismissible", patch["_c"]
    assert_equal "ListTile", patch["content"]["_c"]
    assert_equal "Container", patch["background"]["_c"]
    assert_equal "Container", patch["secondary_background"]["_c"]
    assert_equal 0.2, patch["cross_axis_end_offset"]
    assert_equal "endToStart", patch["dismiss_direction"]
    assert_equal({ "end_to_start" => 0.4 }, patch["dismiss_thresholds"])
    assert_equal 150, patch["movement_duration"]
    assert_equal 250, patch["resize_duration"]
    assert_equal true, patch["on_confirm_dismiss"]
    assert_equal true, patch["on_dismiss"]
    assert_equal true, patch["on_update"]
  end

  def test_dismissible_defaults_match_flet
    control = Ruflet.dismissible(Ruflet.text("Swipe"))

    assert_equal 0.0, control.props["cross_axis_end_offset"]
    assert_equal "horizontal", control.props["dismiss_direction"]
    assert_equal({}, control.props["dismiss_thresholds"])
    assert_equal 200, control.props["movement_duration"]
    assert_equal 300, control.props["resize_duration"]
  end

  def test_dismissible_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.dismissible }
    assert_raises(ArgumentError) { Ruflet.dismissible(Ruflet.text("Hidden", visible: false)) }
  end

  def test_secondary_background_requires_visible_background_like_flet
    assert_raises(ArgumentError) do
      Ruflet.dismissible(Ruflet.text("Swipe"), secondary_background: Ruflet.container(bgcolor: "#ff0000"))
    end

    assert_raises(ArgumentError) do
      Ruflet.dismissible(
        Ruflet.text("Swipe"),
        background: Ruflet.container(bgcolor: "#00ff00", visible: false),
        secondary_background: Ruflet.container(bgcolor: "#ff0000")
      )
    end
  end

  def test_dismiss_thresholds_must_be_between_zero_and_one_like_flet
    assert_raises(ArgumentError) { Ruflet.dismissible(Ruflet.text("Swipe"), dismiss_thresholds: { horizontal: -0.1 }) }
    assert_raises(ArgumentError) { Ruflet.dismissible(Ruflet.text("Swipe"), dismiss_thresholds: { horizontal: 1.1 }) }
  end

  def test_dismiss_and_update_events_expose_direction_details
    events = []
    control = Ruflet.dismissible(
      Ruflet.text("Swipe"),
      on_dismiss: ->(event) { events << [event.name, event.direction] },
      on_update: ->(event) { events << [event.name, event.direction, event.progress, event.reached] }
    )
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )
    page.add(control)

    page.dispatch_event(target: control.wire_id, name: "dismiss", data: { "direction" => "startToEnd" })
    page.dispatch_event(target: control.wire_id, name: "update", data: { "direction" => "startToEnd", "progress" => 0.5, "reached" => true })

    assert_equal [["dismiss", "startToEnd"], ["update", "startToEnd", 0.5, true]], events
  end
end
