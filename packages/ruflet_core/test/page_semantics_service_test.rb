# frozen_string_literal: true

require_relative "test_helper"

class PageSemanticsServiceTest < Minitest::Test
  def test_semantics_service_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)

    service = page.semantics_service(data: { "message" => "Saved" }, key: "semantics")

    assert_equal "semanticsservice", service.type
    assert_equal "SemanticsService", service.to_patch["_c"]
    assert_equal({ "message" => "Saved" }, service.props["data"])
    assert_equal "semantics", service.props["key"]
    assert_same service, page.service(:semantics_service)
  end

  def test_semantics_service_object_methods_use_flet_payload_shape
    sent = []
    page = build_page(sent)
    service = page.semantics_service

    service.announce_message("Saved", rtl: true, assertiveness: "assertive")
    service.announce_tooltip("Tap to save")
    service.get_accessibility_features

    message_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "announce_message" }
    tooltip_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "announce_tooltip" }
    features_payload = sent.reverse.map(&:last).find { |payload| payload["name"] == "get_accessibility_features" }

    refute_nil message_payload
    refute_nil tooltip_payload
    refute_nil features_payload
    assert_equal({ "message" => "Saved", "rtl" => true, "assertiveness" => "assertive" }, message_payload["args"])
    assert_equal({ "message" => "Tap to save" }, tooltip_payload["args"])
    assert_nil features_payload["args"]
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
