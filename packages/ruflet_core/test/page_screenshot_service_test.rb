# frozen_string_literal: true

require_relative "test_helper"

class PageScreenshotServiceTest < Minitest::Test
  def test_screenshot_returns_page_service_with_flet_wire_name
    sent = []
    page = build_page(sent)
    content = Ruflet.text(value: "Capture me")

    service = page.screenshot(content: content, tooltip: "Capture area", visible: false)

    assert_equal "screenshot", service.type
    assert_equal "Screenshot", service.to_patch["_c"]
    assert_same content, service.props["content"]
    assert_equal "Capture area", service.props["tooltip"]
    assert_equal false, service.props["visible"]
    assert_same service, page.service(:screenshot)
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
