# frozen_string_literal: true

require_relative "test_helper"

class PageClientUpdatesTest < Minitest::Test
  def test_live_brightness_is_available_before_the_callback_without_navigation
    page = Ruflet::Page.new(session_id: "test",
      client_details: { "route" => "/settings", "platform_brightness" => "light" },
      sender: ->(*) {})
    observed = nil
    page.on(:platform_brightness_change) do |_event|
      observed = [page.platform_brightness, page.client_details["platform_brightness"], page.route]
    end
    page.apply_client_update(1, "platform_brightness" => "dark")
    page.dispatch_event(target: 1, name: "platform_brightness_change", data: "dark")
    assert_equal ["dark", "dark", "/settings"], observed
    page.apply_client_update("page", width: 440, height: 956)
    assert_equal 440, page.width
    assert_equal 956, page.client_details["height"]
  end

  def test_client_route_update_does_not_swallow_the_following_route_event
    page = Ruflet::Page.new(session_id: "test", client_details: { "route" => "/" }, sender: ->(*) {})
    received = []
    page.on_route_change = ->(event) { received << page.route }
    page.apply_client_update(1, "route" => "/gallery")
    page.dispatch_event(target: 1, name: "route_change", data: { route: "/gallery" })
    assert_equal ["/gallery"], received
  end
end
