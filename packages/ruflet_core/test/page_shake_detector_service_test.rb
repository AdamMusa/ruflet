# frozen_string_literal: true

require_relative "test_helper"

class PageShakeDetectorServiceTest < Minitest::Test
  def test_shake_detector_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.shake_detector(
      minimum_shake_count: 2,
      shake_count_reset_time_ms: 3_000,
      shake_slop_time_ms: 500,
      shake_threshold_gravity: 2.7
    )

    assert_equal "shakedetector", service.type
    assert_equal "ShakeDetector", service.to_patch["_c"]
    assert_equal 2, service.props["minimum_shake_count"]
    assert_equal 3_000, service.props["shake_count_reset_time_ms"]
    assert_equal 500, service.props["shake_slop_time_ms"]
    assert_equal 2.7, service.props["shake_threshold_gravity"]
    assert_same service, page.service(:shake_detector)
  end

  def test_shake_detector_keeps_event_handler
    sent = []
    page = build_page(sent)

    service = page.shake_detector(on_shake: ->(_event) {})

    assert service.has_handler?(:shake)
    assert_equal true, service.props["on_shake"]
  end

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
