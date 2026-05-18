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

  private

  def build_page(sent)
    Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )
  end
end
