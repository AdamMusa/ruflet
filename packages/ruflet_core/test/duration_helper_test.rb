# frozen_string_literal: true

require_relative "test_helper"

class DurationHelperTest < Minitest::Test
  def test_ruflet_duration_returns_milliseconds
    assert_equal 2000, Ruflet.duration(seconds: 2)
    assert_equal 90_500, Ruflet.duration(minutes: 1, seconds: 30, milliseconds: 500)
    assert_equal 0, Ruflet.duration
  end

  def test_every_entry_point_agrees_with_dsl_duration
    parts = { hours: 1, minutes: 2, seconds: 3 }
    expected = Ruflet::DSL.duration(**parts)

    assert_equal 3_723_000, expected
    assert_equal expected, Ruflet.duration(**parts)
    assert_equal expected, Ruflet::UI.duration(**parts)
    assert_equal expected, Ruflet::WidgetBuilder.new.duration(**parts)
  end

  def test_duration_inside_a_builder_block_is_not_a_child_control
    captured = nil
    column = Ruflet.column do
      captured = duration(seconds: 1)
      text("Hello")
    end

    assert_equal 1000, captured
    assert_equal ["Text"], column.to_patch["controls"].map { |child| child["_c"] }
  end

  def test_duration_is_usable_as_a_control_property
    dismissible = Ruflet.dismissible(
      Ruflet.text("Swipe"),
      movement_duration: Ruflet.duration(milliseconds: 750)
    )

    assert_equal 750, dismissible.to_patch["movement_duration"]
  end
end
