# frozen_string_literal: true

require_relative "test_helper"

class RufletSafeAreaCompatibilityTest < Minitest::Test
  def test_safe_area_accepts_positional_content_and_serializes_current_flet_props
    area = Ruflet.safe_area(
      Ruflet.column([Ruflet.text("Body")]),
      avoid_intrusions_bottom: false,
      avoid_intrusions_left: true,
      avoid_intrusions_right: false,
      avoid_intrusions_top: true,
      maintain_bottom_view_padding: true,
      minimum_padding: { left: 8, top: 4 },
      expand: true
    )

    patch = area.to_patch

    assert_equal "SafeArea", patch["_c"]
    assert_equal "Column", patch["content"]["_c"]
    assert_equal false, patch["avoid_intrusions_bottom"]
    assert_equal true, patch["avoid_intrusions_left"]
    assert_equal false, patch["avoid_intrusions_right"]
    assert_equal true, patch["avoid_intrusions_top"]
    assert_equal true, patch["maintain_bottom_view_padding"]
    assert_equal({ "left" => 8, "top" => 4 }, patch["minimum_padding"])
    assert_equal true, patch["expand"]
  end

  def test_compact_alias_uses_same_control
    area = Ruflet.safearea(Ruflet.text("Body"))

    assert_equal "safearea", area.type
    assert_equal "SafeArea", area.to_patch["_c"]
  end

  def test_safe_area_defaults_match_flet
    area = Ruflet.safe_area(Ruflet.text("Body"))

    assert_equal true, area.props["avoid_intrusions_bottom"]
    assert_equal true, area.props["avoid_intrusions_left"]
    assert_equal true, area.props["avoid_intrusions_right"]
    assert_equal true, area.props["avoid_intrusions_top"]
    assert_equal false, area.props["maintain_bottom_view_padding"]
    assert_equal 0, area.props["minimum_padding"]
  end

  def test_safe_area_requires_visible_content_like_flet
    assert_raises(ArgumentError) { Ruflet.safe_area }
    assert_raises(ArgumentError) { Ruflet.safe_area(Ruflet.text("Hidden", visible: false)) }

    area = Ruflet.safe_area(Ruflet.text("Shown"))
    assert_equal "Shown", area.props["content"].props["value"]
  end
end
