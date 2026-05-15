# frozen_string_literal: true

require_relative "test_helper"

class RufletCardCompatibilityTest < Minitest::Test
  def test_card_accepts_positional_content_and_serializes_current_flet_props
    card = Ruflet.card(
      Ruflet.container(content: Ruflet.text("Card body"), padding: 10),
      bgcolor: "#ABCDEF",
      clip_behavior: "antiAlias",
      elevation: 3,
      margin: { left: 8, right: 8 },
      semantic_container: false,
      shadow_color: "#123456",
      shape: { border_radius: 12 },
      show_border_on_foreground: false,
      variant: "outlined"
    )

    patch = card.to_patch

    assert_equal "Card", patch["_c"]
    assert_equal "Container", patch["content"]["_c"]
    assert_equal "Text", patch["content"]["content"]["_c"]
    assert_equal "Card body", patch["content"]["content"]["value"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal "antiAlias", patch["clip_behavior"]
    assert_equal 3, patch["elevation"]
    assert_equal({ "left" => 8, "right" => 8 }, patch["margin"])
    assert_equal false, patch["semantic_container"]
    assert_equal "#123456", patch["shadow_color"]
    assert_equal({ "border_radius" => 12 }, patch["shape"])
    assert_equal false, patch["show_border_on_foreground"]
    assert_equal "outlined", patch["variant"]
  end

  def test_card_allows_no_content_like_flet
    patch = Ruflet.card(elevation: 1).to_patch

    assert_equal "Card", patch["_c"]
    refute patch.key?("content")
  end

  def test_card_rejects_negative_elevation_like_flet
    error = assert_raises(ArgumentError) { Ruflet.card(elevation: -1) }

    assert_match(/elevation/, error.message)
  end
end
