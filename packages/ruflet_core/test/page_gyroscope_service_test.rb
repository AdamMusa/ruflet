# frozen_string_literal: true

require_relative "test_helper"

class PageGyroscopeServiceTest < Minitest::Test
  def test_gyroscope_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.gyroscope(enabled: false, cancel_on_error: false, interval: 100)

    assert_equal "gyroscope", service.type
    assert_equal "Gyroscope", service.to_patch["_c"]
    assert_equal false, service.props["enabled"]
    assert_equal false, service.props["cancel_on_error"]
    assert_equal 100, service.props["interval"]
    assert_same service, page.service(:gyroscope)
  end

  def test_gyroscope_keeps_event_handlers
    sent = []
    page = build_page(sent)

    service = page.gyroscope(on_reading: ->(_event) {}, on_error: ->(_event) {})

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
