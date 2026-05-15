# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoButtonCompatibilityTest < Minitest::Test
  def test_cupertino_button_accepts_positional_content_and_serializes_current_flet_props
    content = Ruflet.text("Tap me")
    button = Ruflet.cupertino_button(
      content,
      bgcolor: "#ABCDEF",
      color: "#123456",
      disabled_bgcolor: "#EEEEEE",
      focus_color: "#BBBBBB",
      icon: "add",
      icon_color: "#00FF00",
      padding: 12,
      url: "https://example.com",
      on_click: ->(_event) {}
    )

    patch = button.to_patch

    assert_equal "CupertinoButton", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "Tap me", patch["content"]["value"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "#123456", patch["color"]
    assert_equal "#eeeeee", patch["disabled_bgcolor"]
    assert_equal "#bbbbbb", patch["focus_color"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("add"), patch["icon"]
    assert_equal "#00ff00", patch["icon_color"]
    assert_equal 12, patch["padding"]
    assert_equal "https://example.com", patch["url"]
    assert_equal true, patch["on_click"]
  end

  def test_cupertino_button_defaults_match_flet
    button = Ruflet.cupertino_button

    assert_equal "center", button.props["alignment"]
    assert_equal false, button.props["autofocus"]
    assert_equal({ "all" => 8.0 }, button.props["border_radius"])
    assert_equal 0.4, button.props["opacity_on_click"]
    assert_equal "large", button.props["size"]
  end

  def test_cupertino_button_rejects_opacity_on_click_outside_flet_range
    assert_raises(ArgumentError) { Ruflet.cupertino_button(opacity_on_click: -0.1) }
    assert_raises(ArgumentError) { Ruflet.cupertino_button(opacity_on_click: 1.1) }
  end

  def test_filled_and_tinted_buttons_inherit_cupertino_button_behavior
    filled = Ruflet.cupertino_filled_button("Fill", opacity_on_click: 0.2)
    tinted = Ruflet.cupertino_tinted_button("Tint", opacity_on_click: 0.3)

    assert_equal "CupertinoFilledButton", filled.to_patch["_c"]
    assert_equal "Fill", filled.to_patch["content"]
    assert_equal "center", filled.props["alignment"]
    assert_equal 0.2, filled.props["opacity_on_click"]

    assert_equal "CupertinoTintedButton", tinted.to_patch["_c"]
    assert_equal "Tint", tinted.to_patch["content"]
    assert_equal "large", tinted.props["size"]
    assert_equal 0.3, tinted.props["opacity_on_click"]
  end

  def test_compact_aliases_use_same_controls
    assert_equal "CupertinoButton", Ruflet.cupertinobutton.to_patch["_c"]
    assert_equal "CupertinoFilledButton", Ruflet.cupertinofilledbutton.to_patch["_c"]
    assert_equal "CupertinoTintedButton", Ruflet.cupertinotintedbutton.to_patch["_c"]
  end
end
