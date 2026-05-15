# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoAppBarCompatibilityTest < Minitest::Test
  def test_cupertino_app_bar_serializes_current_flet_props
    app_bar = Ruflet.cupertino_app_bar(
      automatic_background_visibility: false,
      automatically_imply_leading: true,
      automatically_imply_title: true,
      bgcolor: "#ABCDEF",
      border: { bottom: { color: "#111111", width: 1 } },
      brightness: "light",
      enable_background_filter_blur: false,
      large: true,
      leading: Ruflet.icon("palette"),
      padding: { left: 16, right: 16 },
      previous_page_title: "Back",
      title: "Settings",
      trailing: Ruflet.icon("search"),
      transition_between_routes: false
    )

    patch = app_bar.to_patch

    assert_equal "CupertinoAppBar", patch["_c"]
    assert_equal false, patch["automatic_background_visibility"]
    assert_equal true, patch["automatically_imply_leading"]
    assert_equal true, patch["automatically_imply_title"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "bottom" => { "color" => "#111111", "width" => 1 } }, patch["border"])
    assert_equal "light", patch["brightness"]
    assert_equal false, patch["enable_background_filter_blur"]
    assert_equal true, patch["large"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal({ "left" => 16, "right" => 16 }, patch["padding"])
    assert_equal "Back", patch["previous_page_title"]
    assert_equal "Settings", patch["title"]
    assert_equal "Icon", patch["trailing"]["_c"]
    assert_equal false, patch["transition_between_routes"]
  end

  def test_cupertino_app_bar_defaults_match_flet
    app_bar = Ruflet.cupertino_app_bar

    assert_equal false, app_bar.props["large"]
    assert_equal true, app_bar.props["transition_between_routes"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoAppBar", Ruflet.cupertinoappbar.to_patch["_c"]
  end
end
