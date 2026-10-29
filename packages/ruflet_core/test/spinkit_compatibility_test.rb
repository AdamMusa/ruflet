# frozen_string_literal: true

require_relative "test_helper"

class RufletSpinkitCompatibilityTest < Minitest::Test
  VARIANTS = Ruflet::UI::MaterialControlMethods::SPINKIT_VARIANTS

  def test_every_spinkit_variant_serializes_as_a_distinct_client_control
    VARIANTS.each do |variant|
      patch = Ruflet.spinkit(variant => { color: "#12ABEF", size: 42, duration: 900 }).to_patch

      assert_equal "RufletSpinKit", patch["_c"]
      assert_equal variant.to_s, patch["variant"]
      assert_equal "#12abef", patch["color"]
      assert_equal 42, patch["size"]
      assert_equal 900, patch["duration"]
    end
  end

  def test_spinkit_accepts_variant_specific_renderer_options
    wave = Ruflet.spinkit(wave: { item_count: 7, wave_type: "center" }).to_patch
    piano = Ruflet.spinkit(piano_wave: { item_count: 4 }).to_patch
    ring = Ruflet.spinkit(ring: { line_width: 3.5 }).to_patch
    dual_ring = Ruflet.spinkit(dual_ring: { line_width: 2 }).to_patch
    spinning_lines = Ruflet.spinkit(spinning_lines: { line_width: 1.5 }).to_patch
    ripple = Ruflet.spinkit(ripple: { border_width: 2 }).to_patch

    assert_equal "RufletSpinKit", wave["_c"]
    assert_equal 7, wave["item_count"]
    assert_equal "center", wave["wave_type"]
    assert_equal 4, piano["item_count"]
    assert_equal 3.5, ring["line_width"]
    assert_equal 2, dual_ring["line_width"]
    assert_equal 1.5, spinning_lines["line_width"]
    assert_equal 2, ripple["border_width"]
    assert_equal "end", Ruflet.spinkit(wave: { wave_type: :end }).to_patch["wave_type"]
  end

  def test_spinkit_leaves_variant_option_defaults_to_the_renderer
    patch = Ruflet.spinkit(wave: {}).to_patch

    %w[border_width item_count line_width wave_type].each do |key|
      refute patch.key?(key), "#{key} should fall back to the renderer default"
    end
  end

  def test_spinkit_rejects_missing_unknown_or_multiple_variants
    assert_raises(ArgumentError) { Ruflet.spinkit }
    assert_raises(ArgumentError) { Ruflet.spinkit(unknown: {}) }
    assert_raises(ArgumentError) { Ruflet.spinkit(circle: {}, wave: {}) }
    assert_raises(ArgumentError) { Ruflet.spinkit(circle: "blue") }
  end
end
