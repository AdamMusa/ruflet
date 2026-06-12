# frozen_string_literal: true

require_relative "test_helper"

# Parity with Flet's canonical multi-view routing pattern:
#
#   def main(page):
#     def route_change(e):
#       page.views.clear()
#       page.views.append(ft.View("/", [...]))
#       if page.route == "/store":
#         page.views.append(ft.View("/store", [...]))
#       page.update()
#     def view_pop(e):
#       page.views.pop()
#       page.go(page.views[-1].route)
#     page.on_route_change = route_change
#     page.on_view_pop = view_pop
#     page.go(page.route)
#
# A "complex app" drives its whole UI from page.route + the page.views stack:
# go() updates the route and fires on_route_change, the handler rebuilds the
# stack, and the client back button sends a view_pop event that pops it.
class RufletNavigationStackRoutingTest < Minitest::Test
  def make_page(route: "/")
    sent = []
    page = Ruflet::Page.new(
      session_id: "nav",
      client_details: { "route" => route },
      sender: ->(action, payload) { sent << [action, payload] }
    )
    [page, sent]
  end

  def build_view(route, label)
    Ruflet::UI::ControlFactory.build(
      :view,
      route: route,
      controls: [Ruflet::UI::ControlFactory.build(:text, value: label)]
    )
  end

  # Reads the routes of the view stack from the most recent view patch frame.
  def last_view_stack(sent)
    sent.reverse_each do |(_action, payload)|
      next unless payload.is_a?(Hash) && payload["id"] == 1

      op = Array(payload["patch"]).find { |o| o.is_a?(Array) && o[2] == "views" }
      next unless op

      return Array(op[3]).map { |view_patch| view_patch["route"] }
    end
    nil
  end

  def wire_router(page)
    page.on_route_change = lambda do |_event|
      page.views.clear
      page.views << build_view("/", "Home")
      page.views << build_view("/store", "Store") if page.route == "/store"
      page.update
    end

    page.on_view_pop = lambda do |_event|
      page.views.pop
      page.go(page.views.last.route)
    end
  end

  def test_go_sets_route_and_fires_on_route_change
    page, sent = make_page
    seen = []
    page.on_route_change = ->(event) { seen << event.data }

    page.go("/store")

    assert_equal "/store", page.route
    assert_equal ["/store"], seen
    refute_empty sent, "go must flush a view patch"
  end

  def test_route_change_builds_a_single_view_at_root
    page, sent = make_page
    wire_router(page)

    page.go("/")

    assert_equal ["/"], last_view_stack(sent), "root route shows one view"
  end

  def test_navigating_deeper_pushes_onto_the_view_stack
    page, sent = make_page
    wire_router(page)

    page.go("/")
    page.go("/store")

    assert_equal "/store", page.route
    assert_equal ["/", "/store"], last_view_stack(sent),
                 "navigating to /store stacks it on top of /"
  end

  def test_view_pop_from_the_client_back_button_pops_the_stack
    page, sent = make_page
    wire_router(page)
    page.go("/")
    page.go("/store")
    assert_equal ["/", "/store"], last_view_stack(sent)

    # The Flutter client sends a `view_pop` page event (id 1) when the user
    # presses the AppBar back arrow or the system back gesture.
    sent.clear
    page.dispatch_event(target: 1, name: "view_pop", data: nil)

    assert_equal "/", page.route, "popping returns to the previous route"
    assert_equal ["/"], last_view_stack(sent), "the store view is popped off"
  end

  def test_view_control_exposes_its_route
    view = build_view("/store", "Store")

    assert_equal "/store", view.route
    assert_equal "/store", view.props["route"]
  end

  def test_views_reader_is_the_live_mutable_stack
    page, = make_page

    page.views << build_view("/", "Home")
    page.views << build_view("/a", "A")

    assert_equal ["/", "/a"], page.views.map(&:route)

    page.views.pop
    assert_equal ["/"], page.views.map(&:route)
  end

  def test_query_params_survive_go
    page, = make_page
    page.go("/search", q: "shoes", page: 2)

    assert_equal "shoes", page.query["q"]
    assert_equal "2", page.query["page"].to_s
  end
end
