# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoBottomSheetCompatibilityTest < Minitest::Test
  def test_cupertino_bottom_sheet_accepts_positional_content_and_serializes_current_flet_props
    content = Ruflet.text("Sheet")
    sheet = Ruflet.cupertino_bottom_sheet(
      content,
      bgcolor: "#ABCDEF",
      height: 216,
      modal: true,
      padding: { top: 6 },
      on_dismiss: ->(_event) {}
    )

    patch = sheet.to_patch

    assert_equal "CupertinoBottomSheet", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal "Sheet", patch["content"]["value"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal 216, patch["height"]
    assert_equal true, patch["modal"]
    assert_equal({ "top" => 6 }, patch["padding"])
    assert_equal true, patch["on_dismiss"]
  end

  def test_cupertino_bottom_sheet_defaults_match_flet
    sheet = Ruflet.cupertino_bottom_sheet(Ruflet.text("Sheet"))

    assert_equal false, sheet.props["modal"]
  end

  def test_cupertino_bottom_sheet_requires_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_bottom_sheet }
  end

  def test_compact_alias_uses_same_control
    assert_equal "CupertinoBottomSheet", Ruflet.cupertinobottomsheet(Ruflet.text("Sheet")).to_patch["_c"]
  end
end
