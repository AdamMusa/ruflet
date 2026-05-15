# frozen_string_literal: true

require_relative "test_helper"

class RufletAppBarCompatibilityTest < Minitest::Test
  def test_app_bar_serializes_current_flet_props_with_snake_case_keys
    app_bar = Ruflet.app_bar(
      leading: Ruflet.icon("menu"),
      title: "Dashboard",
      actions: [Ruflet.icon_button(icon: "search"), Ruflet.icon_button(icon: "more_vert")],
      actions_padding: { right: 8 },
      adaptive: true,
      automatically_imply_leading: false,
      bgcolor: "#ABCDEF",
      center_title: true,
      clip_behavior: "antiAlias",
      color: "#123456",
      elevation: 4,
      elevation_on_scroll: 8,
      exclude_header_semantics: true,
      force_material_transparency: true,
      leading_width: 48,
      secondary: true,
      shadow_color: "#222222",
      shape: { border_radius: 8 },
      title_spacing: 0,
      title_text_style: { size: 18 },
      toolbar_height: 72,
      toolbar_opacity: 0.75,
      toolbar_text_style: { weight: "bold" }
    )

    patch = app_bar.to_patch

    assert_equal "AppBar", patch["_c"]
    assert_equal "Icon", patch["leading"]["_c"]
    assert_equal "Dashboard", patch["title"]
    assert_equal ["IconButton", "IconButton"], patch["actions"].map { |action| action["_c"] }
    assert_equal({ "right" => 8 }, patch["actions_padding"])
    assert_equal true, patch["adaptive"]
    assert_equal false, patch["automatically_imply_leading"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal true, patch["center_title"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal "#123456", patch["color"]
    assert_equal 4, patch["elevation"]
    assert_equal 8, patch["elevation_on_scroll"]
    assert_equal true, patch["exclude_header_semantics"]
    assert_equal true, patch["force_material_transparency"]
    assert_equal 48, patch["leading_width"]
    assert_equal true, patch["secondary"]
    assert_equal "#222222", patch["shadow_color"]
    assert_equal({ "border_radius" => 8 }, patch["shape"])
    assert_equal 0, patch["title_spacing"]
    assert_equal({ "size" => 18 }, patch["title_text_style"])
    assert_equal 72, patch["toolbar_height"]
    assert_equal 0.75, patch["toolbar_opacity"]
    assert_equal({ "weight" => "bold" }, patch["toolbar_text_style"])
  end

  def test_app_bar_rejects_toolbar_opacity_outside_flet_range
    assert_raises(ArgumentError) { Ruflet.app_bar(toolbar_opacity: -0.01) }
    assert_raises(ArgumentError) { Ruflet.app_bar(toolbar_opacity: 1.01) }
  end

  def test_page_add_serializes_app_bar_as_view_appbar
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    page.add(Ruflet.text("Body"), appbar: Ruflet.app_bar(title: Ruflet.text("Home")))

    view = sent.last[1]["patch"][1][3].first
    assert_equal "AppBar", view["appbar"]["_c"]
    assert_equal "Text", view["appbar"]["title"]["_c"]
    assert_equal "Home", view["appbar"]["title"]["value"]
  end
end
