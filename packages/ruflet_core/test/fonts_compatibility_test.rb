# frozen_string_literal: true

require_relative "test_helper"

# Mirrors the flet fonts cookbook: https://flet.dev/docs/cookbook/fonts/
class RufletFontsCompatibilityTest < Minitest::Test
  def test_page_fonts_serialize_family_to_source_map_like_flet
    sent = []
    page = build_page(sent)

    page.fonts = {
      "Kanit" => "https://raw.githubusercontent.com/google/fonts/master/ofl/kanit/Kanit-Bold.ttf",
      "Open Sans" => "/fonts/OpenSans-Regular.ttf"
    }
    page.add(Ruflet.text("hello"))

    patch = sent.last[1]["patch"]
    assert_equal(
      {
        "Kanit" => "https://raw.githubusercontent.com/google/fonts/master/ofl/kanit/Kanit-Bold.ttf",
        "Open Sans" => "/fonts/OpenSans-Regular.ttf"
      },
      patch_value(patch, "fonts")
    )
    # fonts are a page-level prop, never duplicated onto the view (matches flet)
    refute patch_value(patch, "views").first.key?("fonts")
  end

  def test_theme_font_family_sets_app_default_font_like_flet
    sent = []
    page = build_page(sent)

    page.theme = { font_family: "Kanit" }
    page.add(Ruflet.text("hello"))

    patch = sent.last[1]["patch"]
    assert_equal({ "font_family" => "Kanit" }, patch_value(patch, "theme"))
  end

  def test_text_font_family_overrides_per_control_like_flet
    text = Ruflet.text("This text uses the Open Sans font", font_family: "Open Sans")

    patch = text.to_patch
    assert_equal "Text", patch["_c"]
    assert_equal "Open Sans", patch["font_family"]
  end

  def test_text_font_family_fallback_serializes_like_flet
    text = Ruflet.text(
      "fallback",
      font_family: "Kanit",
      font_family_fallback: ["Open Sans", "Roboto"]
    )

    patch = text.to_patch
    assert_equal "Kanit", patch["font_family"]
    assert_equal ["Open Sans", "Roboto"], patch["font_family_fallback"]
  end

  def test_system_font_family_passes_through_untouched_like_flet
    # System fonts (e.g. "Consolas") are used directly without registering them.
    text = Ruflet.text("code", font_family: "Consolas")

    assert_equal "Consolas", text.to_patch["font_family"]
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end
end
