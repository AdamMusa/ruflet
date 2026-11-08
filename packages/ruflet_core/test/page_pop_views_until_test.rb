# frozen_string_literal: true

require_relative "test_helper"

# page.pop_views_until(route, result:) mirrors Flet's Page.pop_views_until:
# it removes every view above the first view whose route matches, makes that
# route current, and hands +result+ to page.on_views_pop_until together with
# the destination view.
class RufletPagePopViewsUntilTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
    @home = Ruflet.view(route: "/", controls: [Ruflet.text("Home")])
    @list = Ruflet.view(route: "/list", controls: [Ruflet.text("List")])
    @item = Ruflet.view(route: "/list/item", controls: [Ruflet.text("Item")])
    @edit = Ruflet.view(route: "/list/item/edit", controls: [Ruflet.text("Edit")])
    @page.views = [@home, @list, @item, @edit]
    @page.route = "/list/item/edit"
    @page.update
    @sent.clear
  end

  def test_pops_views_above_the_target_and_delivers_the_result
    events = []
    @page.on_views_pop_until = ->(event) { events << [event.route, event.result, event.view] }

    @page.pop_views_until("/list", result: { "saved" => 42 })

    assert_equal [@home, @list], @page.views
    assert_equal "/list", @page.route
    assert_equal [["/list", { "saved" => 42 }, @list]], events
  end

  def test_keeps_the_caller_views_array_and_sends_one_view_patch
    views = @page.views

    @page.pop_views_until("/")

    assert_same views, @page.views
    assert_equal [@home], views
    patches = @sent.select { |_action, payload| payload.is_a?(Hash) && payload["id"] == 1 && payload["patch"] }
    assert_equal 1, patches.length
    view_ops = patches.first.last["patch"].select { |op| op[2] == "views" }
    assert_equal 1, view_ops.length
    assert_equal ["View"], view_ops.first[3].map { |view| view["_c"] }
  end

  def test_fires_route_change_after_views_pop_until_when_the_route_changes
    order = []
    @page.on_views_pop_until = ->(_event) { order << :views_pop_until }
    @page.on_route_change = ->(event) { order << [:route_change, event.data] }

    @page.pop_views_until("/list/item")

    assert_equal [:views_pop_until, [:route_change, "/list/item"]], order
  end

  def test_does_not_fire_route_change_when_the_route_is_already_current
    routes = []
    @page.on_route_change = ->(event) { routes << event.data }

    @page.pop_views_until("/list/item/edit", result: "noop")

    assert_equal [@home, @list, @item, @edit], @page.views
    assert_empty routes
  end

  def test_matches_the_first_view_with_the_route
    again = Ruflet.view(route: "/list", controls: [Ruflet.text("List again")])
    @page.views = [@home, @list, @item, again]

    @page.pop_views_until("/list")

    assert_equal [@home, @list], @page.views
  end

  def test_unknown_route_raises_and_leaves_the_stack_alone
    error = assert_raises(ArgumentError) { @page.pop_views_until("/missing") }

    assert_includes error.message, "/missing"
    assert_equal [@home, @list, @item, @edit], @page.views
    assert_equal "/list/item/edit", @page.route
    assert_empty @sent
  end

  def test_works_without_a_handler_and_with_a_block_handler
    @page.pop_views_until("/list/item")
    assert_equal [@home, @list, @item], @page.views

    results = []
    @page.on(:views_pop_until) { |event| results << event.result }
    @page.pop_views_until("/", result: "done")

    assert_equal ["done"], results
    assert_equal [@home], @page.views
  end

  def test_client_views_pop_until_event_exposes_its_route
    seen = []
    @page.on_views_pop_until = ->(event) { seen << [event.route, event.result, event.view, event.value] }

    @page.dispatch_event(target: 1, name: "views_pop_until", data: { "route" => "/home" })

    assert_equal [["/home", nil, nil, "/home"]], seen
  end
end
