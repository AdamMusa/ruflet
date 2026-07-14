# frozen_string_literal: true

require_relative "test_helper"

class PageScreenshotControlTest < Minitest::Test
  def test_screenshot_returns_visual_control_without_poisoning_service_registry
    sent = []
    page = build_page(sent)
    content = Ruflet.text(value: "Capture me")

    screenshot = page.screenshot(content: content, tooltip: "Capture area", visible: false)

    assert_equal "screenshot", screenshot.type
    assert_equal "Screenshot", screenshot.to_patch["_c"]
    assert_same content, screenshot.props["content"]
    assert_equal "Capture area", screenshot.props["tooltip"]
    assert_equal false, screenshot.props["visible"]
    assert_empty page.services
    assert_raises(ArgumentError) { page.service(:screenshot) }
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
