# frozen_string_literal: true

require_relative "test_helper"

class RufletColorNormalizationTest < Minitest::Test
  def test_named_colors_are_canonicalized_on_top_level_color_props
    patch = Ruflet.container(bgcolor: :blue_grey, ink_color: "DeepOrange500").to_patch

    assert_equal "bluegrey", patch["bgcolor"]
    assert_equal "deeporange500", patch["ink_color"]
  end

  def test_named_colors_accept_ruby_style_names
    patch = Ruflet.container(bgcolor: :deep_orange_500, ink_color: :primary_container).to_patch

    assert_equal "deeporange500", patch["bgcolor"]
    assert_equal "primarycontainer", patch["ink_color"]
  end

  def test_named_colors_accept_hyphenated_and_spaced_names
    patch = Ruflet.container(
      bgcolor: "Deep Orange 500",
      ink_color: "deep-orange-accent-400",
      border: { color: "Surface Container Highest" }
    ).to_patch

    assert_equal "deeporange500", patch["bgcolor"]
    assert_equal "deeporangeaccent400", patch["ink_color"]
    assert_equal({ "color" => "surfacecontainerhighest" }, patch["border"])
  end

  def test_nested_style_and_state_colors_are_canonicalized
    patch = Ruflet.text(
      "hello",
      style: {
        color: :primary_container,
        decoration_color: "LightBlue200",
        shadow: { color: "#ABCDEF" }
      }
    ).to_patch

    assert_equal "primarycontainer", patch["style"]["color"]
    assert_equal "lightblue200", patch["style"]["decoration_color"]
    assert_equal "#abcdef", patch["style"]["shadow"]["color"]
  end

  def test_state_color_maps_and_gradient_color_arrays_are_canonicalized
    patch = Ruflet.navigation_bar(
      destinations: [
        Ruflet.navigation_bar_destination(icon: "home", label: "Home"),
        Ruflet.navigation_bar_destination(icon: "person", label: "Profile")
      ],
      overlay_color: { pressed: :white_70, hovered: "#ABCDEF" },
      indicator_color: :green_accent_400
    ).to_patch

    gradient = Ruflet.container(gradient: { colors: ["#ABCDEF", :deep_purple_500] }).to_patch["gradient"]

    assert_equal({ "pressed" => "white70", "hovered" => "#abcdef" }, patch["overlay_color"])
    assert_equal "greenaccent400", patch["indicator_color"]
    assert_equal({ "colors" => ["#abcdef", "deeppurple500"] }, gradient)
  end

  def test_theme_color_scheme_seed_is_canonicalized
    patch = Ruflet.container(
      theme: { color_scheme_seed: :teal_700 },
      dark_theme: { color_scheme_seed: "#ABCDEF" }
    ).to_patch

    assert_equal({ "color_scheme_seed" => "teal700" }, patch["theme"])
    assert_equal({ "color_scheme_seed" => "#abcdef" }, patch["dark_theme"])
  end
end
