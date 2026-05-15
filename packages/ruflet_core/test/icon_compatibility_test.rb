# frozen_string_literal: true

require_relative "test_helper"

class RufletIconCompatibilityTest < Minitest::Test
  def test_icon_accepts_icon_as_first_argument_like_flet
    icon = Ruflet.icon(
      "add",
      color: "#ABCDEF",
      size: 32,
      semantics_label: "Create",
      shadows: [{ blur_radius: 2 }],
      fill: 0.5,
      apply_text_scaling: true,
      grade: 1,
      weight: 400,
      optical_size: 24,
      blend_mode: "src_in"
    )

    patch = icon.to_patch

    assert_equal "Icon", patch["_c"]
    assert_equal 65604, patch["icon"]
    assert_equal "#abcdef", patch["color"]
    assert_equal 32, patch["size"]
    assert_equal "Create", patch["semantics_label"]
    assert_equal [{ "blur_radius" => 2 }], patch["shadows"]
    assert_equal 0.5, patch["fill"]
    assert_equal true, patch["apply_text_scaling"]
    assert_equal 1, patch["grade"]
    assert_equal 400, patch["weight"]
    assert_equal 24, patch["optical_size"]
    assert_equal "src_in", patch["blend_mode"]
  end

  def test_icon_keeps_keyword_icon
    icon = Ruflet.icon(icon: "add")

    assert_equal 65604, icon.to_patch["icon"]
  end
end
