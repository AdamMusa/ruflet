# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoCheckboxCompatibilityTest < Minitest::Test
  def test_cupertino_checkbox_serializes_current_flet_props
    checkbox = Ruflet.cupertino_checkbox(
      label: "Accept",
      value: true,
      active_color: "#ABCDEF",
      check_color: "#111111",
      fill_color: { selected: "#222222", hovered: "#333333" },
      focus_color: "#444444",
      label_position: "left",
      semantics_label: "accept terms",
      shape: { border_radius: 4 },
      spacing: 12,
      tristate: true,
      on_change: ->(_event) {}
    )

    patch = checkbox.to_patch

    assert_equal "CupertinoCheckbox", patch["_c"]
    assert_equal "Accept", patch["label"]
    assert_equal true, patch["value"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#111111", patch["check_color"]
    assert_equal({ "selected" => "#222222", "hovered" => "#333333" }, patch["fill_color"])
    assert_equal "#444444", patch["focus_color"]
    assert_equal "left", patch["label_position"]
    assert_equal "accept terms", patch["semantics_label"]
    assert_equal({ "border_radius" => 4 }, patch["shape"])
    assert_equal 12, patch["spacing"]
    assert_equal true, patch["tristate"]
    assert_equal true, patch["on_change"]
  end

  def test_cupertino_checkbox_defaults_match_flet
    checkbox = Ruflet.cupertino_checkbox

    assert_equal false, checkbox.props["autofocus"]
    assert_equal "right", checkbox.props["label_position"]
    assert_equal 10, checkbox.props["spacing"]
    assert_equal false, checkbox.props["tristate"]
    assert_equal false, checkbox.props["value"]
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoCheckbox", Ruflet.cupertinocheckbox.to_patch["_c"]
  end
end
