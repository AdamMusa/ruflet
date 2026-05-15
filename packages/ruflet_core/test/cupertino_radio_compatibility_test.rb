# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoRadioCompatibilityTest < Minitest::Test
  def test_cupertino_radio_serializes_current_flet_props
    radio = Ruflet.cupertino_radio(
      value: "red",
      label: "Red",
      active_color: "#FF0000",
      fill_color: "#AA0000",
      focus_color: "#BB0000",
      inactive_color: "#CC0000",
      label_position: "left",
      mouse_cursor: "click",
      toggleable: true,
      use_checkmark_style: true,
      on_blur: ->(_event) {},
      on_focus: ->(_event) {}
    )

    patch = radio.to_patch

    assert_equal "CupertinoRadio", patch["_c"]
    assert_equal "red", patch["value"]
    assert_equal "Red", patch["label"]
    assert_equal "#ff0000", patch["active_color"]
    assert_equal "#aa0000", patch["fill_color"]
    assert_equal "#bb0000", patch["focus_color"]
    assert_equal "#cc0000", patch["inactive_color"]
    assert_equal "left", patch["label_position"]
    assert_equal "click", patch["mouse_cursor"]
    assert_equal true, patch["toggleable"]
    assert_equal true, patch["use_checkmark_style"]
    assert_equal true, patch["on_blur"]
    assert_equal true, patch["on_focus"]
  end

  def test_cupertino_radio_defaults_match_flet
    radio = Ruflet.cupertino_radio

    assert_equal false, radio.props["autofocus"]
    assert_equal "right", radio.props["label_position"]
    assert_equal false, radio.props["toggleable"]
    assert_equal false, radio.props["use_checkmark_style"]
    assert_equal "", radio.props["value"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoRadio", Ruflet.cupertinoradio.to_patch["_c"]
  end
end
