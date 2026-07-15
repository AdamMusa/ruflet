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

  def test_spinkit_rejects_missing_unknown_or_multiple_variants
    assert_raises(ArgumentError) { Ruflet.spinkit }
    assert_raises(ArgumentError) { Ruflet.spinkit(unknown: {}) }
    assert_raises(ArgumentError) { Ruflet.spinkit(circle: {}, wave: {}) }
    assert_raises(ArgumentError) { Ruflet.spinkit(circle: "blue") }
  end
end
