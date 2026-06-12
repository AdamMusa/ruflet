# frozen_string_literal: true

require_relative "test_helper"

class RufletRouteStackTest < Minitest::Test
  def make_page(route: "/")
    sent = []
    page = Ruflet::Page.new(
      session_id: "rs",
      client_details: { "route" => route },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    [page, sent]
  end

  def view(route, label)
    Ruflet::UI::ControlFactory.build(
      :view,
      route: route,
      controls: [Ruflet::UI::ControlFactory.build(:text, value: label)]
    )
  end

  def last_view_stack(sent)
    sent.reverse_each do |(_action, payload)|
      next unless payload.is_a?(Hash) && payload["id"] == 1

      op = Array(payload["patch"]).find { |o| o.is_a?(Array) && o[2] == "views" }
      return Array(op[3]).map { |v| v["route"] } if op
    end
    nil
  end

  def test_block_form_rebuilds_the_stack_from_the_route
    page, sent = make_page
    Ruflet::Rails.routed(page) do |route, nav|
      nav.push(view("/", "Home"))
      nav.push(view("/store", "Store")) if route == "/store"
    end

    assert_equal ["/"], last_view_stack(sent), "starts at root with one view"

    page.go("/store")
    assert_equal ["/", "/store"], last_view_stack(sent), "deep route stacks on top"
  end

  def test_map_form_with_on
    page, sent = make_page
    Ruflet::Rails::RouteStack.new(page)
      .on("/") { |nav| nav.push(view("/", "Home")) }
      .on("/store") { |nav| nav.push(view("/", "Home")); nav.push(view("/store", "Store")) }
      .start

    assert_equal ["/"], last_view_stack(sent)

    page.go("/store")
    assert_equal ["/", "/store"], last_view_stack(sent)
  end

  def test_client_back_button_pops_the_stack
    page, sent = make_page
    Ruflet::Rails.routed(page) do |route, nav|
      nav.push(view("/", "Home"))
      nav.push(view("/store", "Store")) if route == "/store"
    end
    page.go("/store")
    assert_equal ["/", "/store"], last_view_stack(sent)

    sent.clear
    page.dispatch_event(target: 1, name: "view_pop", data: nil)

    assert_equal "/", page.route
    assert_equal ["/"], last_view_stack(sent), "back pops /store and returns to /"
  end

  def test_starts_at_the_clients_initial_route
    page, sent = make_page(route: "/store")
    Ruflet::Rails.routed(page) do |route, nav|
      nav.push(view("/", "Home"))
      nav.push(view("/store", "Store")) if route == "/store"
    end

    assert_equal ["/", "/store"], last_view_stack(sent),
                 "a deep-linked initial route renders its full stack"
  end
end
