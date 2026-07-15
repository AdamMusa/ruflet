# frozen_string_literal: true

require_relative "test_helper"

class AnimationCompatibilityTest < Minitest::Test
  def test_animation_serializes_like_flet_animation_value
    control = Ruflet.container(
      width: 100,
      height: 80,
      opacity: 0.5,
      animate: Ruflet.animation(700, curve: Ruflet::AnimationCurve::BOUNCE_OUT),
      animate_opacity: true,
      animate_scale: 300
    )

    patch = control.to_patch

    assert_equal({ "duration" => 700, "curve" => "bounceOut" }, patch["animate"])
    assert_equal true, patch["animate_opacity"]
    assert_equal 300, patch["animate_scale"]
  end

  def test_animation_defaults_to_linear_curve_and_copies_overrides
    base = Ruflet::Animation.new(duration: 250)
    copied = base.copy(duration: 500, curve: Ruflet::AnimationCurve::EASE_IN_OUT_CUBIC)

    assert_equal({ "duration" => 250, "curve" => "linear" }, base.to_h)
    assert_equal({ "duration" => 500, "curve" => "easeInOutCubic" }, copied.to_h)
  end

  def test_animation_style_serializes_flet_shape
    sheet = Ruflet.bottom_sheet(
      content: Ruflet.text("Hello"),
      animation_style: Ruflet.animation_style(
        duration: 200,
        reverse_duration: 150,
        curve: Ruflet::AnimationCurve::EASE_OUT,
        reverse_curve: Ruflet::AnimationCurve::EASE_IN
      )
    )

    assert_equal(
      {
        "duration" => 200,
        "reverse_duration" => 150,
        "curve" => "easeOut",
        "reverse_curve" => "easeIn"
      },
      sheet.to_patch.fetch("animation_style")
    )
  end

  def test_animation_curve_exposes_flet_curve_values
    assert_equal "bounceIn", Ruflet::AnimationCurve::BOUNCE_IN
    assert_equal "fastLinearToSlowEaseIn", Ruflet::AnimationCurve::FAST_LINEAR_TO_SLOW_EASE_IN
    assert_equal "fastOutSlowIn", Ruflet::AnimationCurve::FAST_OUT_SLOWIN
    assert_includes Ruflet::AnimationCurve.values, "slowMiddle"
  end
end
