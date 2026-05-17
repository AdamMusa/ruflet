# frozen_string_literal: true

require_relative "test_helper"

class PageAccelerometerServiceTest < Minitest::Test
  def test_accelerometer_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.accelerometer(enabled: false, cancel_on_error: false, interval: 100)

    assert_equal "accelerometer", service.type
    assert_equal "Accelerometer", service.to_patch["_c"]
    assert_equal false, service.props["enabled"]
    assert_equal false, service.props["cancel_on_error"]
    assert_equal 100, service.props["interval"]
    assert_same service, page.service(:accelerometer)
  end

  def test_accelerometer_keeps_event_handlers
    sent = []
    page = build_page(sent)
    reading_handler = ->(_event) {}
    error_handler = ->(_event) {}

    service = page.accelerometer(on_reading: reading_handler, on_error: error_handler)

    assert service.has_handler?(:reading)
    assert service.has_handler?(:error)
    assert_equal true, service.props["on_reading"]
    assert_equal true, service.props["on_error"]
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
