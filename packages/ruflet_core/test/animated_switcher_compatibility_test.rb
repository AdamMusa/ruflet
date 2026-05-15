# frozen_string_literal: true

require_relative "test_helper"

class RufletAnimatedSwitcherCompatibilityTest < Minitest::Test
  def test_animated_switcher_accepts_positional_content_and_serializes_current_flet_props
    switcher = Ruflet.animated_switcher(
      Ruflet.text("Hello"),
      transition: "scale",
      duration: 500,
      reverse_duration: 100,
      switch_in_curve: "bounceOut",
      switch_out_curve: "bounceIn",
      width: 200,
      height: 100
    )

    patch = switcher.to_patch

    assert_equal "AnimatedSwitcher", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "scale", patch["transition"]
    assert_equal 500, patch["duration"]
    assert_equal 100, patch["reverse_duration"]
    assert_equal "bounceOut", patch["switch_in_curve"]
    assert_equal "bounceIn", patch["switch_out_curve"]
    assert_equal 200, patch["width"]
    assert_equal 100, patch["height"]
  end

  def test_compact_alias_uses_same_control
    switcher = Ruflet.animatedswitcher(Ruflet.text("Hello"))

    assert_equal "animatedswitcher", switcher.type
    assert_equal "AnimatedSwitcher", switcher.to_patch["_c"]
  end

  def test_animated_switcher_defaults_match_flet
    switcher = Ruflet.animated_switcher(Ruflet.text("Hello"))

    assert_equal 1000, switcher.props["duration"]
    assert_equal 1000, switcher.props["reverse_duration"]
    assert_equal "linear", switcher.props["switch_in_curve"]
    assert_equal "linear", switcher.props["switch_out_curve"]
    assert_equal "fade", switcher.props["transition"]
  end

  def test_animated_switcher_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.animated_switcher }
    assert_raises(ArgumentError) { Ruflet.animated_switcher(Ruflet.text("Hidden", visible: false)) }

    switcher = Ruflet.animated_switcher(Ruflet.text("Shown"))
    assert_equal "Shown", switcher.props["content"].props["value"]
  end
end
