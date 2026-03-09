# frozen_string_literal: true

require_relative "test_helper"

class TypedUiModelsTest < Minitest::Test
  def test_text_style_serializes_through_control_props
    style = Ruflet::TextStyle.new(size: 16, color: "#112233", italic: true)
    control = Ruflet.text(value: "hello", style: style)
    patch = control.to_patch

    assert_equal 16, patch["style"]["size"]
    assert_equal "#112233", patch["style"]["color"]
    assert_equal true, patch["style"]["italic"]
  end

  def test_text_style_copy
    base = Ruflet::TextStyle.new(size: 14, color: "#000000")
    next_style = base.copy(size: 18)

    assert_equal 14, base.size
    assert_equal 18, next_style.size
    assert_equal "#000000", next_style.color
  end

  def test_event_exposes_typed_data_fields
    evt = Ruflet::Event.new(
      name: "tap",
      target: "1",
      raw_data: { "k" => "touch", "l" => { "x" => 11, "y" => 22 }, "g" => { "x" => 33, "y" => 44 } },
      page: nil,
      control: nil
    )

    assert_instance_of Ruflet::Events::TapEvent, evt.typed_data
    assert_equal "touch", evt.kind
    assert_equal 11, evt.local_position.x
    assert_equal 44, evt.global_position.y
  end
end
