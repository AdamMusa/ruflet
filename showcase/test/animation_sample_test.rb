# frozen_string_literal: true

require "minitest/autorun"

class AnimationSampleTest < Minitest::Test
  def test_animation_sample_builds_ruflet_from_animated_character_parts
    source = File.read(File.expand_path("../sections_media/animation.rb", __dir__))

    assert_includes source, "letter_grids"
    assert_includes source, "Ruflet".chars.inspect
    assert_includes source, "animate_position: duration"
    assert_includes source, "animate_rotation: duration"
    assert_includes source, "Random.new"
    refute_includes source, "value: \"Ruflet\""
  end
end
