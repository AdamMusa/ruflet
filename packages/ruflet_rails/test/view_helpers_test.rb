# frozen_string_literal: true

require_relative "test_helper"

class RufletViewHelpersTest < Minitest::Test
  def helper
    @helper ||= Class.new { include Ruflet::Rails::ViewHelpers }.new
  end

  # --- native annotations ------------------------------------------------

  def test_ruflet_appbar_wraps_block_content_with_appbar_attributes
    html = helper.ruflet_appbar("Inbox", leading: { icon: "menu", action: "drawer" }) { helper.ruflet_appbar_action("search", "/search") }.to_s
    assert_includes html, "<header"
    assert_includes html, "data-ruflet-appbar"
    assert_includes html, 'hidden="true"'
    assert_includes html, "&quot;leading&quot;"
    assert_includes html, "&quot;drawer&quot;"
    assert_includes html, 'data-ruflet-title="Inbox"'
    assert_includes html, 'data-ruflet-icon="{&quot;icon&quot;:&quot;search&quot;'
    assert_includes html, 'href="/search"'
    assert_includes html, "</header>"
  end

  def test_ruflet_bottom_nav_wraps_items
    html = helper.ruflet_bottom_nav do
      helper.ruflet_nav_item("Home", "/", icon: "house", selected: true) +
        helper.ruflet_nav_item("Profile", "/profile", icon: "person")
    end.to_s
    assert_includes html, "<nav"
    assert_includes html, "data-ruflet-tabs"
    assert_includes html, 'hidden="true"'
    assert_includes html, 'data-ruflet-icon="{&quot;icon&quot;:&quot;house&quot;'
    assert_includes html, '&quot;label&quot;:&quot;Home&quot;'
    assert_includes html, "data-ruflet-selected", "the active item is marked"
    assert_includes html, 'href="/profile"'
  end

  def test_native_helpers_accept_custom_ruflet_payloads
    html = helper.ruflet_bottom_nav(payload: { bgcolor: "#101010", indicator_color: "#eeeeee" }) do
      helper.ruflet_nav_item("Home", "/", icon: "house", payload: { selected_icon: "home_filled", tooltip: "Go home" })
    end.to_s

    assert_includes html, "&quot;bgcolor&quot;:&quot;#101010&quot;"
    assert_includes html, "&quot;indicator_color&quot;:&quot;#eeeeee&quot;"
    assert_includes html, "&quot;selected_icon&quot;:&quot;home_filled&quot;"
    assert_includes html, "&quot;tooltip&quot;:&quot;Go home&quot;"
  end

  def test_ruflet_drawer_wraps_items
    html = helper.ruflet_drawer do
      helper.ruflet_drawer_item("Home", "/", icon: "home", selected: true) +
        helper.ruflet_drawer_item("Settings", "/settings", icon: "settings", nav: :push)
    end.to_s
    assert_includes html, "<nav"
    assert_includes html, "data-ruflet-drawer"
    assert_includes html, 'hidden="true"'
    assert_includes html, 'data-ruflet-icon="{&quot;icon&quot;:&quot;home&quot;'
    assert_includes html, '&quot;label&quot;:&quot;Settings&quot;'
    assert_includes html, '&quot;action&quot;:&quot;push&quot;'
    assert_includes html, "data-ruflet-selected"
    assert_includes html, 'href="/settings"'
  end

  def test_drawer_and_rail_helpers_accept_custom_ruflet_payloads
    drawer = helper.ruflet_drawer(payload: { bgcolor: "#ffffff", width: 320 }) do
      helper.ruflet_drawer_item("Home", "/", icon: "home", payload: { selected_tile_color: "#ddeeff" })
    end.to_s
    rail = helper.ruflet_navigation_rail(payload: { bgcolor: "#111111", min_width: 88 }) do
      helper.ruflet_rail_item("Home", "/", icon: "home", payload: { indicator_color: "#444444" })
    end.to_s

    assert_includes drawer, "&quot;width&quot;:320"
    assert_includes drawer, "&quot;selected_tile_color&quot;:&quot;#ddeeff&quot;"
    assert_includes rail, "&quot;min_width&quot;:88"
    assert_includes rail, "&quot;indicator_color&quot;:&quot;#444444&quot;"
  end

  def test_ruflet_navigation_rail_wraps_items
    html = helper.ruflet_navigation_rail(extended: true) do
      helper.ruflet_rail_item("Home", "/", icon: "home", selected: true) +
        helper.ruflet_rail_item("Inbox", "/inbox", icon: "mail")
    end.to_s
    assert_includes html, "<nav"
    assert_includes html, "data-ruflet-rail"
    assert_includes html, 'hidden="true"'
    assert_includes html, "&quot;extended&quot;:true"
    assert_includes html, 'data-ruflet-icon="{&quot;icon&quot;:&quot;home&quot;'
    assert_includes html, '&quot;label&quot;:&quot;Inbox&quot;'
    assert_includes html, "data-ruflet-selected"
    assert_includes html, 'href="/inbox"'
  end

  def test_service_action_helpers_emit_ruflet_actions
    share = helper.ruflet_share_link("Share", "/x", text: "Hello").to_s
    assert_includes share, "data-ruflet-action"
    assert_includes share, "&quot;component&quot;:&quot;share&quot;"
    assert_includes share, "&quot;text&quot;:&quot;Hello&quot;"

    copy = helper.ruflet_copy_button("Copy", text: "Secret").to_s
    assert_includes copy, "<button"
    assert_includes copy, "&quot;component&quot;:&quot;clipboard&quot;"
    assert_includes copy, "&quot;toast&quot;:&quot;Copied&quot;"

    launch = helper.ruflet_launch_link("Open", "https://example.com").to_s
    assert_includes launch, "&quot;component&quot;:&quot;url_launcher&quot;"
    assert_includes launch, 'href="https://example.com"'

    haptic = helper.ruflet_haptic_button("Tap", style: "light").to_s
    assert_includes haptic, "&quot;component&quot;:&quot;haptic&quot;"
    assert_includes haptic, "&quot;style&quot;:&quot;light&quot;"
  end

  def test_native_annotation_values_are_html_escaped
    html = helper.ruflet_appbar_action('"><script>alert(1)</script>', "/x").to_s
    refute_includes html, "<script>alert(1)</script>"
    assert_includes html, "&lt;script&gt;"
  end

  def test_extra_kwargs_become_dashed_attributes
    html = helper.ruflet_nav_item("Home", "/x", icon: "house", data_role: "cta").to_s
    assert_includes html, 'data-role="cta"'
  end
end
