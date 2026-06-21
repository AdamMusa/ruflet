# frozen_string_literal: true

require_relative "test_helper"
require "ruflet_ui/ruflet/ui/controls/ruflet_controls"

# Mirrors the flet_spinkit extension: https://flet.dev/docs/controls/spinkit/
# Public API: spinkit(wave: { color: ..., size: ... }) — one variant keyword
# whose value is the props hash.
class RufletSpinkitCompatibilityTest < Minitest::Test
  def test_all_thirty_variants_are_registered_with_flet_wire_names
    expected = Ruflet::UI::Controls::RufletComponents::SPINKIT_WIRE_TO_TYPE
    assert_equal 30, expected.size

    expected.each do |wire, type_key|
      assert_equal wire, Ruflet.control(type_key.to_sym).to_patch["_c"],
                   "#{type_key} should serialize as #{wire}"
    end
  end

  def test_spinkit_keyword_selects_variant_and_serializes_common_props
    patch = Ruflet.spinkit(double_bounce: { color: "yellow", size: 50, duration: 700 }).to_patch
    assert_equal "SpinKitDoubleBounce", patch["_c"]
    assert_equal "yellow", patch["color"]
    assert_equal 50, patch["size"]
    assert_equal 700, patch["duration"]
  end

  def test_bare_call_works_without_ruflet_prefix
    # Usable like text()/container()/video() with no `Ruflet.` prefix — the
    # forwarder is a private Kernel method, called here without a receiver.
    assert_equal "SpinKitWave", spinkit(wave: { color: "red" }).to_patch["_c"]
  end

  def test_wave_variant_specific_props
    patch = Ruflet.spinkit(wave: { item_count: 6, wave_type: :center }).to_patch
    assert_equal "SpinKitWave", patch["_c"]
    assert_equal 6, patch["item_count"]
    assert_equal "center", patch["wave_type"]
  end

  def test_ring_ripple_and_line_width_variants
    assert_equal 4, Ruflet.spinkit(ring: { line_width: 4 }).to_patch["line_width"]
    assert_equal 5, Ruflet.spinkit(dual_ring: { line_width: 5 }).to_patch["line_width"]
    assert_equal 2, Ruflet.spinkit(spinning_lines: { line_width: 2 }).to_patch["line_width"]
    assert_equal 6, Ruflet.spinkit(ripple: { border_width: 6 }).to_patch["border_width"]
    assert_equal 5, Ruflet.spinkit(piano_wave: { item_count: 5 }).to_patch["item_count"]
  end

  def test_named_color_is_canonicalized_like_other_controls
    assert_equal "bluegrey", Ruflet.spinkit(circle: { color: :blue_grey }).to_patch["color"]
  end

  def test_size_must_be_non_negative
    assert_raises(ArgumentError) { Ruflet.spinkit(pulse: { size: -1 }) }
  end

  def test_unknown_attribute_is_rejected
    assert_raises(ArgumentError) { Ruflet.spinkit(pulse: { bogus: 1 }) }
  end

  def test_unknown_variant_is_rejected
    assert_raises(ArgumentError) { Ruflet.spinkit(nope: {}) }
  end

  def test_requires_exactly_one_variant
    assert_raises(ArgumentError) { Ruflet.spinkit }
    assert_raises(ArgumentError) { Ruflet.spinkit(wave: {}, ring: {}) }
  end
end
