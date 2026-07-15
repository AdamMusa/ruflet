# frozen_string_literal: true

require_relative "test_helper"

class RufletBadgeCompatibilityTest < Minitest::Test
  def test_badge_accepts_positional_label_and_serializes_current_flet_props
    badge = Ruflet.badge(
      "3",
      alignment: { x: 1, y: -1 },
      bgcolor: "#ABCDEF",
      label_visible: false,
      large_size: 18,
      offset: { dx: 2, dy: -2 },
      padding: { left: 4, right: 4 },
      small_size: 8,
      text_color: "#123456",
      text_style: { size: 10 }
    )

    patch = badge.to_patch

    assert_equal "Badge", patch["_c"]
    assert_equal "3", patch["label"]
    assert_equal({ "x" => 1, "y" => -1 }, patch["alignment"])
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal false, patch["label_visible"]
    assert_equal 18, patch["large_size"]
    assert_equal({ "dx" => 2, "dy" => -2 }, patch["offset"])
    assert_equal({ "left" => 4, "right" => 4 }, patch["padding"])
    assert_equal 8, patch["small_size"]
    assert_equal "#123456", patch["text_color"]
    assert_equal({ "size" => 10 }, patch["text_style"])
  end

  def test_badge_accepts_control_label_like_flet
    badge = Ruflet.badge(Ruflet.text("new"))
    patch = badge.to_patch

    assert_equal "Text", patch["label"]["_c"]
    assert_equal "new", patch["label"]["value"]
  end

  def test_badge_serializes_when_embedded_on_control
    button = Ruflet.icon_button("phone", badge: Ruflet.badge("10"))
    patch = button.to_patch

    assert_equal "Badge", patch["badge"]["_c"]
    assert_equal "10", patch["badge"]["label"]
  end

  def test_badge_rejects_negative_sizes_like_flet
    %i[large_size small_size].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.badge(prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end
end
