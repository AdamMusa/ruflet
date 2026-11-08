# frozen_string_literal: true

require_relative "test_helper"

# Ruflet.animation / animation_style build the plain values the engine's
# parseAnimation ({duration, curve}) and parseAnimationStyle ({duration,
# reverse_duration, curve, reverse_curve}) read; durations are milliseconds.
class RufletAnimationValuesTest < Minitest::Test
  def setup
    Ruflet::DSL._reset_pending_app!
  end

  def teardown
    Ruflet::DSL._reset_pending_app!
  end

  def test_animation_is_a_duration_and_curve
    assert_equal({ "duration" => 300, "curve" => "ease_in" }, Ruflet.animation(300, curve: "ease_in"))
    assert_equal({ "duration" => 300, "curve" => "ease_in" }, Ruflet.animation(duration: 300, curve: :ease_in))
    assert_equal({ "duration" => 1500 }, Ruflet.animation(seconds: 1, milliseconds: 500))
    assert_equal({ "duration" => 0 }, Ruflet.animation)
  end

  def test_animation_style_keeps_only_given_parts
    assert_equal(
      { "duration" => 200, "reverse_duration" => 100, "curve" => "decelerate", "reverse_curve" => "ease_out" },
      Ruflet.animation_style(duration: 200, reverse_duration: 100, curve: :decelerate, reverse_curve: "ease_out")
    )
    assert_equal({ "duration" => 250 }, Ruflet.animation_style(duration: { milliseconds: 250 }))
    assert_equal({}, Ruflet.animation_style)
  end

  def test_invalid_values_raise
    assert_raises(ArgumentError) { Ruflet.animation(-1) }
    assert_raises(ArgumentError) { Ruflet.animation("fast") }
    assert_raises(ArgumentError) { Ruflet.animation(300, speed: 2) }
    assert_raises(ArgumentError) { Ruflet.animation_style(duration: -5) }
    assert_raises(ArgumentError) { Ruflet.animation_style(bounce: true) }
  end

  def test_every_dsl_entry_point_builds_the_same_value
    expected = { "duration" => 300, "curve" => "linear" }

    assert_equal expected, Ruflet.animation(300, curve: "linear")
    assert_equal expected, Ruflet::UI.animation(300, curve: "linear")
    assert_equal expected, Ruflet::DSL.animation(300, curve: "linear")
    assert_equal expected, Ruflet::DSL.app.animation(300, curve: "linear")
    assert_equal expected, animation(300, curve: "linear")
    assert_equal({ "duration" => 10 }, Ruflet::DSL.app.animation_style(duration: 10))
  end

  def test_values_serialize_as_control_props
    box = Ruflet.container(
      content: Ruflet.text("x"),
      animate_opacity: Ruflet.animation(400, curve: "ease_out"),
      opacity: 0.5
    )
    sheet = Ruflet.bottom_sheet(content: Ruflet.text("s"), animation_style: Ruflet.animation_style(duration: 200))

    assert_equal({ "duration" => 400, "curve" => "ease_out" }, box.to_patch["animate_opacity"])
    assert_equal({ "duration" => 200 }, sheet.to_patch["animation_style"])
  end

  def test_textfield_alias_takes_the_value_like_text_field
    assert_equal "TextField", Ruflet.textfield(label: "Name").to_patch["_c"]
    assert_equal "hello", Ruflet.textfield("hello", label: "Name").to_patch["value"]
    assert_equal "hello", Ruflet::DSL.app.textfield("hello").to_patch["value"]
    assert_equal "hello", textfield("hello").to_patch["value"]
  end
end
