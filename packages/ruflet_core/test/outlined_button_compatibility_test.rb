# frozen_string_literal: true

require_relative "test_helper"

class RufletOutlinedButtonCompatibilityTest < Minitest::Test
  def test_outlined_button_accepts_positional_content_and_serializes_current_flet_props
    button = Ruflet.outlined_button(
      "Secondary",
      icon: "add",
      icon_color: "#ABCDEF",
      style: { side: { color: "#111111", width: 1 } },
      clip_behavior: "anti_alias",
      url: "https://flet.dev",
      on_blur: ->(_event) {},
      on_click: ->(_event) {},
      on_focus: ->(_event) {},
      on_hover: ->(_event) {},
      on_long_press: ->(_event) {}
    )

    patch = button.to_patch

    assert_equal "OutlinedButton", patch["_c"]
    assert_equal "Secondary", patch["content"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("add"), patch["icon"]
    assert_equal "#abcdef", patch["icon_color"]
    assert_equal({ "side" => { "color" => "#111111", "width" => 1 } }, patch["style"])
    assert_equal "anti_alias", patch["clip_behavior"]
    assert_equal "https://flet.dev", patch["url"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_click"]
    assert_equal true, patch["on_focus"]
    assert_equal true, patch["on_hover"]
    assert_equal true, patch["on_long_press"]
  end

  def test_outlined_button_defaults_match_flet
    button = Ruflet.outlined_button("Secondary")

    assert_equal false, button.props["autofocus"]
    assert_equal "none", button.props["clip_behavior"]
  end

  def test_outlined_button_requires_content_or_icon_like_flet
    assert_raises(ArgumentError) { Ruflet.outlined_button }
  end

  def test_compact_alias_uses_same_control
    assert_equal "OutlinedButton", Ruflet.outlinedbutton("Secondary").to_patch["_c"]
  end
end
