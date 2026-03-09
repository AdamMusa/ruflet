# frozen_string_literal: true

require_relative "test_helper"

class GestureEventsTypedTest < Minitest::Test
  def build_event(name, data)
    Ruflet::Event.new(name: name, target: "1", raw_data: data, page: nil, control: nil)
  end

  def test_long_press_move_update_event_decodes_offsets
    evt = build_event(
      "long_press_move_update",
      {
        "l" => { "x" => 1, "y" => 2 },
        "g" => { "x" => 3, "y" => 4 },
        "of" => { "x" => 5, "y" => 6 },
        "lofo" => { "x" => 7, "y" => 8 }
      }
    )

    assert_instance_of Ruflet::Events::LongPressMoveUpdateEvent, evt.typed_data
    assert_equal 5, evt.offset_from_origin.x
    assert_equal 8, evt.local_offset_from_origin.y
  end

  def test_force_press_event_decodes_pressure
    evt = build_event("force_press", { "l" => [1, 2], "g" => [3, 4], "p" => 0.75 })

    assert_instance_of Ruflet::Events::ForcePressEvent, evt.typed_data
    assert_equal 0.75, evt.pressure
    assert_equal 3, evt.global_position.x
  end

  def test_multi_tap_event_decodes_correct_touches
    evt = build_event("multi_tap", { "ct" => true })

    assert_instance_of Ruflet::Events::MultiTapEvent, evt.typed_data
    assert_equal true, evt.correct_touches
  end

  def test_pointer_event_decodes_extended_fields
    evt = build_event(
      "hover",
      {
        "k" => "mouse",
        "l" => { "x" => 10, "y" => 20 },
        "g" => { "x" => 30, "y" => 40 },
        "ts" => 123,
        "dev" => 7,
        "ps" => 0.2,
        "pMin" => 0.0,
        "pMax" => 1.0,
        "dist" => 2.1,
        "distMax" => 10.0,
        "size" => 0.5,
        "rMj" => 9.0,
        "rMn" => 8.0,
        "rMin" => 1.0,
        "rMax" => 12.0,
        "or" => 0.9,
        "tilt" => 0.3,
        "ld" => { "x" => 1, "y" => -1 },
        "gd" => { "x" => 2, "y" => -2 }
      }
    )

    assert_instance_of Ruflet::Events::PointerEvent, evt.typed_data
    assert_equal "mouse", evt.kind
    assert_equal 7, evt.device
    assert_equal 0.2, evt.pressure
    assert_equal 123, evt.timestamp.milliseconds
    assert_equal(-2, evt.global_delta.y)
  end

  def test_drag_down_event_decodes
    evt = build_event("drag_down", { "l" => { "x" => 2, "y" => 3 }, "g" => { "x" => 4, "y" => 5 } })

    assert_instance_of Ruflet::Events::DragDownEvent, evt.typed_data
    assert_equal 2, evt.local_position.x
    assert_equal 5, evt.global_position.y
  end

  def test_state_change_event_maps_generic_typed_payload
    evt = build_event("state_change", { "state" => "resume" })

    assert_instance_of Ruflet::Events::StateChangeEvent, evt.typed_data
    assert_equal "resume", evt.state
    assert_equal "resume", evt.value
  end

  def test_change_event_maps_generic_typed_payload
    evt = build_event("change", { "value" => "hello" })

    assert_instance_of Ruflet::Events::ChangeEvent, evt.typed_data
    assert_equal "hello", evt.value
  end

  def test_unknown_event_has_nil_typed_data
    evt = build_event("totally_unknown", { "x" => 1 })
    assert_nil evt.typed_data
  end
end
