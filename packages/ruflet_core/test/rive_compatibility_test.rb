# frozen_string_literal: true

require_relative "test_helper"

class RufletRiveCompatibilityTest < Minitest::Test
  def test_rive_serializes_flet_props_to_wire_keys
    animation = Ruflet.rive(
      "https://cdn.rive.app/animations/vehicles.riv",
      artboard: "Truck",
      use_artboard_size: true,
      alignment: { x: 0, y: 0 },
      fit: "contain",
      speed_multiplier: 1.5,
      animations: %w[idle],
      state_machines: %w[bumpy],
      headers: { "Authorization" => "Bearer t" },
      clip_rect: { left: 0, top: 0, right: 100, bottom: 100 },
      enable_antialiasing: true,
      expand: true
    )

    patch = animation.to_patch

    assert_equal "Rive", patch["_c"]
    assert_equal "https://cdn.rive.app/animations/vehicles.riv", patch["src"]
    # Flet names map to the renderer's wire keys.
    assert_equal "Truck", patch["art_board"]
    refute patch.key?("artboard")
    assert_equal true, patch["use_art_board_size"]
    refute patch.key?("use_artboard_size")
    assert_equal({ "x" => 0, "y" => 0 }, patch["alignment"])
    assert_equal "contain", patch["fit"]
    assert_equal 1.5, patch["speed_multiplier"]
    assert_equal %w[idle], patch["animations"]
    assert_equal %w[bumpy], patch["state_machines"]
    assert_equal({ "Authorization" => "Bearer t" }, patch["headers"])
    assert_equal({ "left" => 0, "top" => 0, "right" => 100, "bottom" => 100 }, patch["clip_rect"])
    assert_equal true, patch["enable_antialiasing"]
    assert_equal true, patch["expand"]
  end

  def test_rive_accepts_wire_key_names_directly
    animation = Ruflet.rive("a.riv", art_board: "Main", use_art_board_size: false)
    patch = animation.to_patch
    assert_equal "Main", patch["art_board"]
    assert_equal false, patch["use_art_board_size"]
  end

  def test_rive_placeholder_is_a_nested_control
    animation = Ruflet.rive("a.riv", placeholder: Ruflet.progress_ring)
    patch = animation.to_patch
    assert_equal "ProgressRing", patch["placeholder"]["_c"]
  end
end
