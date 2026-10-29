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

    assert_equal "BottomSheet", patch["_c"]
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

  IOS_SHEET_KEYWORDS = %i[
    barrier_color dismissible draggable fullscreen maintain_bottom_view_insets_padding
    scrollable show_drag_handle size_constraints use_safe_area
  ].freeze

  def test_cupertino_bottom_sheet_accepts_the_ios_sheet_contract
    sheet = Ruflet.cupertino_bottom_sheet(
      Ruflet.column(controls: [Ruflet.text("Title"), Ruflet.text_field(label: "Name")]),
      barrier_color: "#88112233",
      dismissible: false,
      draggable: true,
      fullscreen: true,
      maintain_bottom_view_insets_padding: false,
      scrollable: true,
      show_drag_handle: true,
      size_constraints: { max_height: 420, max_width: 600 },
      use_safe_area: false
    )

    patch = sheet.to_patch

    assert_equal "BottomSheet", patch["_c"]
    assert_equal "Column", patch["content"]["_c"]
    assert_equal "#88112233", patch["barrier_color"]
    assert_equal false, patch["dismissible"]
    assert_equal true, patch["draggable"]
    assert_equal true, patch["fullscreen"]
    assert_equal false, patch["maintain_bottom_view_insets_padding"]
    assert_equal true, patch["scrollable"]
    assert_equal true, patch["show_drag_handle"]
    assert_equal({ "max_height" => 420, "max_width" => 600 }, patch["size_constraints"])
    assert_equal false, patch["use_safe_area"]
  end

  # The iOS renderer derives draggable from fullscreen (page sheets drag,
  # popups do not), so neither spelling may send a draggable default.
  def test_sheet_defaults_leave_ios_behaviour_to_the_renderer
    [
      Ruflet.cupertino_bottom_sheet(Ruflet.text("Sheet")),
      Ruflet.bottom_sheet(Ruflet.text("Sheet"))
    ].each do |sheet|
      patch = sheet.to_patch
      IOS_SHEET_KEYWORDS.each do |keyword|
        refute patch.key?(keyword.to_s), "#{keyword} must not get a Ruby default"
      end
    end
  end

  def test_legacy_spelling_accepts_every_canonical_ios_sheet_keyword
    canonical = Ruflet::UI::PlatformControlContracts::Components::BottomSheetControl::KEYWORDS
    legacy = Ruflet::UI::Controls::RufletComponents::CupertinoBottomSheetControl
             .instance_method(:initialize).parameters.map(&:last)

    IOS_SHEET_KEYWORDS.each do |keyword|
      assert_includes canonical, keyword
      assert_includes legacy, keyword
    end
    (legacy - %i[id]).each { |keyword| assert_includes canonical, keyword }
  end

  def test_canonical_bottom_sheet_serializes_the_ios_sheet_contract
    patch = Ruflet.bottom_sheet(
      Ruflet.text("Sheet"),
      bgcolor: "#123456",
      height: 320,
      padding: 16,
      fullscreen: true,
      show_drag_handle: true
    ).to_patch

    assert_equal "#123456", patch["bgcolor"]
    assert_equal 320, patch["height"]
    assert_equal 16, patch["padding"]
    assert_equal true, patch["fullscreen"]
    assert_equal true, patch["show_drag_handle"]
  end

  def test_cupertino_bottom_sheet_rejects_material_only_keywords
    assert_raises(ArgumentError) { Ruflet.cupertino_bottom_sheet(Ruflet.text("Sheet"), elevation: 4) }
  end

  def test_cupertino_bottom_sheet_requires_content_like_flet
    assert_raises(ArgumentError) { Ruflet.cupertino_bottom_sheet }
  end

  def test_compact_alias_uses_same_control
    assert_equal "BottomSheet", Ruflet.cupertinobottomsheet(Ruflet.text("Sheet")).to_patch["_c"]
  end
end
