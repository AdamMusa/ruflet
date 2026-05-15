# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoActivityIndicatorCompatibilityTest < Minitest::Test
  def test_cupertino_activity_indicator_serializes_current_flet_props
    indicator = Ruflet.cupertino_activity_indicator(
      animating: false,
      color: "#ABCDEF",
      radius: 30,
      width: 80,
      height: 80
    )

    patch = indicator.to_patch

    assert_equal "CupertinoActivityIndicator", patch["_c"]
    assert_equal false, patch["animating"]
    assert_equal "#abcdef", patch["color"]
    assert_equal 30, patch["radius"]
    assert_equal 80, patch["width"]
    assert_equal 80, patch["height"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoActivityIndicator", Ruflet.cupertinoactivityindicator.to_patch["_c"]
  end

  def test_cupertino_activity_indicator_defaults_match_flet
    indicator = Ruflet.cupertino_activity_indicator

    assert_equal true, indicator.props["animating"]
    assert_equal 10, indicator.props["radius"]
  end

  def test_cupertino_activity_indicator_rejects_non_positive_radius_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_activity_indicator(radius: 0) }
    assert_raises(ArgumentError) { Ruflet.cupertino_activity_indicator(radius: -1) }
  end
end
