# frozen_string_literal: true

require_relative "test_helper"

class RufletRoutesCompatibilityTest < Minitest::Test
  def test_navigate_and_push_route_match_flet_route_helpers
    sent = []
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { sent << [action, payload] }
    )

    routes = []
    page.on_route_change = ->(event) { routes << event.value }

    page.navigate("/store", category: "tea & cake", page: 2)

    assert_equal "/store?category=tea+%26+cake&page=2", page.route
    assert_equal({ "category" => "tea & cake", "page" => "2" }, page.query)
    assert_equal [page.route], routes
    assert_equal page.route, patch_value(sent.last[1]["patch"], "route")

    page.push_route("/cart", coupon: "SAVE 10")

    assert_equal "/cart?coupon=SAVE+10", page.route
    assert_equal({ "coupon" => "SAVE 10" }, page.query)
    assert_equal ["/store?category=tea+%26+cake&page=2", "/cart?coupon=SAVE+10"], routes
  end

  def test_query_reflects_client_route_changes
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/initial?x=1" },
      sender: ->(_action, _payload) {}
    )

    assert_equal({ "x" => "1" }, page.query)

    page.dispatch_event(target: "page", name: "route_change", data: { "route" => "/next?tag=a&tag=b" })

    assert_equal "/next?tag=a&tag=b", page.route
    assert_equal({ "tag" => ["a", "b"] }, page.query)
  end

  private

  def patch_value(patch, key)
    op = patch.find { |candidate| candidate[2] == key }
    op && op[3]
  end
end
