# frozen_string_literal: true

require_relative "test_helper"

class PageGeolocatorServiceTest < Minitest::Test
  def test_geolocator_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.geolocator(configuration: { accuracy: "low" }, on_position_change: ->(_event) {}, on_error: ->(_event) {})

    assert_equal "geolocator", service.type
    assert_equal "Geolocator", service.to_patch["_c"]
    assert_equal({ "accuracy" => "low" }, service.to_patch["configuration"])
    assert_equal true, service.props["on_position_change"]
    assert_equal true, service.props["on_error"]
    assert_same service, page.service(:geolocator)
  end

  def test_geolocator_methods_use_flet_payload_shape
    sent = []
    page = build_page(sent)
    service = page.geolocator

    service.distance_between(1.0, 2.0, 3.0, 4.0)
    service.get_current_position(configuration: { accuracy: "high" })
    service.get_last_known_position
    service.request_permission

    payloads = sent.map(&:last)
    assert_equal(
      {
        "start_latitude" => 1.0,
        "start_longitude" => 2.0,
        "end_latitude" => 3.0,
        "end_longitude" => 4.0
      },
      payloads.find { |payload| payload["name"] == "distance_between" }["args"]
    )
    assert_equal(
      { "configuration" => { "accuracy" => "high" } },
      payloads.find { |payload| payload["name"] == "get_current_position" }["args"]
    )
    assert_nil payloads.find { |payload| payload["name"] == "get_last_known_position" }["args"]
    assert_nil payloads.find { |payload| payload["name"] == "request_permission" }["args"]
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
