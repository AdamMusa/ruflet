# frozen_string_literal: true

require_relative "test_helper"

class RufletListTileChevronCompatibilityTest < Minitest::Test
  def test_list_tile_serializes_chevron
    tile = Ruflet.list_tile(title: "Privacy", chevron: true, on_click: ->(_event) {})
    patch = tile.to_patch

    assert_equal "ListTile", patch["_c"]
    assert_equal true, patch["chevron"]
    assert_equal true, patch["on_click"]
    assert tile.has_handler?(:click)
  end

  def test_chevron_coexists_with_trailing
    patch = Ruflet.list_tile(title: "Wi-Fi", trailing: Ruflet.text("Home"), chevron: true).to_patch

    assert_equal "Text", patch["trailing"]["_c"]
    assert_equal true, patch["chevron"]
  end

  def test_chevron_is_off_unless_requested
    assert_equal false, Ruflet.list_tile(title: "Plain", chevron: false).to_patch["chevron"]
    refute Ruflet.list_tile(title: "Plain").to_patch.key?("chevron")
  end

  def test_every_list_tile_spelling_accepts_chevron
    tiles = [
      Ruflet.listtile(title: "Alias", chevron: true),
      Ruflet.cupertino_list_tile(title: Ruflet.text("Legacy"), chevron: true),
      Ruflet::UI::Controls::RufletComponents::ListTileControl.new(title: "Material", chevron: true),
      Ruflet::UI::Controls::RufletComponents::CupertinoListTileControl.new(title: "Cupertino", chevron: true)
    ]

    assert_equal %w[ListTile ListTile ListTile ListTile], tiles.map { |tile| tile.to_patch["_c"] }
    assert_equal [true, true, true, true], tiles.map { |tile| tile.to_patch["chevron"] }
  end

  def test_list_tile_contract_unions_chevron_from_both_renderers
    assert_includes Ruflet::UI::Controls::RufletComponents::ListTileControl::KEYWORDS, :chevron
    assert_includes Ruflet::UI::Controls::RufletComponents::CupertinoListTileControl::KEYWORDS, :chevron
    assert_includes Ruflet::UI::PlatformControlContracts::Components::ListTileControl::KEYWORDS, :chevron
  end

  def test_list_tile_still_rejects_unknown_keywords
    assert_raises(ArgumentError) { Ruflet.list_tile(title: "Privacy", disclosure: true) }
  end
end
