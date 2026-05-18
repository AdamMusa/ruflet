# frozen_string_literal: true

require_relative "test_helper"

class PageConnectivityServiceTest < Minitest::Test
  def test_connectivity_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.connectivity(data: { "source" => "studio" }, key: "connectivity")

    assert_equal "connectivity", service.type
    assert_equal "Connectivity", service.to_patch["_c"]
    assert_equal({ "source" => "studio" }, service.props["data"])
    assert_equal "connectivity", service.props["key"]
    assert_same service, page.service(:connectivity)
  end

  def test_connectivity_keeps_change_event_handler
    sent = []
    page = build_page(sent)

    service = page.connectivity(on_change: ->(_event) {})

    assert service.has_handler?(:change)
    assert_equal true, service.props["on_change"]
  end

  def test_get_connectivity_uses_flet_method_name
    sent = []
    page = build_page(sent)

    call_id = page.get_connectivity
    refute_nil call_id

    invoke_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get_connectivity" }
    refute_nil invoke_payload
    assert_nil invoke_payload["args"]
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
