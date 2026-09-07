# frozen_string_literal: true

require_relative "test_helper"

class AdsExtensionCompatibilityTest < Minitest::Test
  def test_ad_controls_use_current_flet_wire_types_and_properties
    request = { keywords: ["ruby"], non_personalized_ads: true }
    banner = Ruflet.banner_ad(unit_id: "banner-1", request: request, on_paid: ->(_event) {})
    native = Ruflet.native_ad(unit_id: "native-1", template_style: { template_type: "small" })

    assert_equal "BannerAd", banner.to_patch["_c"]
    assert_equal({ "keywords" => ["ruby"], "non_personalized_ads" => true }, banner.to_patch["request"])
    assert banner.has_handler?(:paid)
    assert_equal "NativeAd", native.to_patch["_c"]
    assert_equal({ "template_type" => "small" }, native.to_patch["template_style"])
  end

  def test_interstitial_show_invokes_flet_method
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    ad = Ruflet.interstitial_ad(unit_id: "interstitial-1")
    page.add(ad)

    ad.show

    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], sent.last[0]
    assert_equal "show", sent.last[1]["name"]
  end
end
