# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoSwitchCompatibilityTest < Minitest::Test
  def test_cupertino_switch_serializes_current_flet_props
    switch = Ruflet.cupertino_switch(
      label: "Wi-Fi",
      value: true,
      active_thumb_image_src: "on.png",
      inactive_thumb_image_src: "off.png",
      active_track_color: "#00FF00",
      focus_color: "#111111",
      inactive_thumb_color: "#222222",
      inactive_track_color: "#333333",
      label_position: "left",
      off_label_color: "#444444",
      on_label_color: "#555555",
      thumb_color: "#666666",
      thumb_icon: { selected: "check" },
      track_outline_color: { default: "#777777" },
      track_outline_width: { default: 2 },
      on_change: ->(_event) {},
      on_image_error: ->(_event) {}
    )

    patch = switch.to_patch

    assert_equal "CupertinoSwitch", patch["_c"]
    assert_equal "Wi-Fi", patch["label"]
    assert_equal true, patch["value"]
    assert_equal "on.png", patch["active_thumb_image_src"]
    assert_equal "off.png", patch["inactive_thumb_image_src"]
    assert_equal "#00ff00", patch["active_track_color"]
    assert_equal "#111111", patch["focus_color"]
    assert_equal "#222222", patch["inactive_thumb_color"]
    assert_equal "#333333", patch["inactive_track_color"]
    assert_equal "left", patch["label_position"]
    assert_equal "#444444", patch["off_label_color"]
    assert_equal "#555555", patch["on_label_color"]
    assert_equal({ "selected" => Ruflet::MaterialIconLookup.codepoint_for("check") }, patch["thumb_icon"])
    assert_equal({ "default" => "#777777" }, patch["track_outline_color"])
    assert_equal({ "default" => 2 }, patch["track_outline_width"])
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_image_error"]
  end

  def test_cupertino_switch_defaults_match_flet
    switch = Ruflet.cupertino_switch

    assert_equal false, switch.props["autofocus"]
    assert_equal "right", switch.props["label_position"]
    assert_equal false, switch.props["value"]
  end

  def test_legacy_image_aliases_map_to_current_flet_names
    switch = Ruflet.cupertino_switch(
      active_thumb_image: "on.png",
      inactive_thumb_image: "off.png"
    )

    assert_equal "on.png", switch.to_patch["active_thumb_image_src"]
    assert_equal "off.png", switch.to_patch["inactive_thumb_image_src"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoSwitch", Ruflet.cupertinoswitch.to_patch["_c"]
  end
end
