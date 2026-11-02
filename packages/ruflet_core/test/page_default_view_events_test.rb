# frozen_string_literal: true

require_relative "test_helper"

# The default page View (page.add without explicit views) is not a registered
# control. Page-level handlers must register as handlers (never travel as a
# Proc), its events must reach them, and a refresh must be acknowledged on it.
class RufletPageDefaultViewEventsTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def invokes
    @sent.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def page_patch
    _action, payload = @sent.reverse.find { |action, p| action == Ruflet::Protocol::ACTIONS[:patch_control] && p["id"] == 1 }
    payload["patch"]
  end

  def page_op(key)
    op = page_patch.find { |candidate| candidate.is_a?(Array) && candidate[2] == key }
    op && op[3]
  end

  def implicit_view
    page_op("views").first
  end

  def procs_in(value, path = "payload")
    case value
    when Proc, Method then [path]
    when Hash then value.flat_map { |k, v| procs_in(v, "#{path}[#{k.inspect}]") }
    when Array then value.each_with_index.flat_map { |v, i| procs_in(v, "#{path}[#{i}]") }
    else []
    end
  end

  def test_page_handlers_register_and_only_flags_reach_the_wire
    @page.on_refresh = ->(_e) {}
    @page.on_scroll = ->(_e) {}
    @page.on_end_reached = ->(_e) {}
    @page.on_resize = ->(_e) {}
    @page.add(Ruflet.text("Body"))

    assert_empty @sent.flat_map { |_action, payload| procs_in(payload) }
    view = implicit_view
    assert_equal true, view["on_refresh"]
    assert_equal true, view["on_scroll"]
    assert_equal true, view["on_end_reached"]
    refute view.key?("on_resize"), "resize is a Page event, not a View event"
    assert_equal true, page_op("on_resize")
    assert_nil page_op("on_refresh")
    assert_equal true, @page.on_refresh
  end

  def test_scroll_from_the_default_view_reaches_the_page_handler
    events = []
    @page.on_scroll = ->(e) { events << [e.name, e.data] }
    @page.add(Ruflet.text("Body"))
    view_id = implicit_view["_i"]
    @sent.clear

    @page.dispatch_event(target: view_id, name: "scroll", data: { "pixels" => 12.0 })

    assert_equal [["scroll", { "pixels" => 12.0 }]], events
    assert_empty @sent, "scroll sends nothing back"
  end

  def test_refresh_from_the_default_view_runs_the_handler_then_acks_the_view
    order = []
    @page.on_refresh = ->(e) do
      order << e.name
      e.page.add(Ruflet.text("Fresh"))
    end
    @page.add(Ruflet.text("Body"))
    view_id = implicit_view["_i"]
    @sent.clear

    @page.dispatch_event(target: view_id, name: "refresh", data: nil)

    assert_equal ["refresh"], order
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], @sent.first.first, "the handler's update goes first"
    assert_equal Ruflet::Protocol::ACTIONS[:invoke_control_method], @sent.last.first
    assert_equal [[view_id, "end_refresh"]], invokes.map { |payload| [payload["control_id"], payload["name"]] }
  end

  def test_refresh_is_acknowledged_even_when_the_handler_raises
    @page.on_refresh = ->(_e) { raise "offline" }
    @page.add(Ruflet.text("Body"))
    view_id = implicit_view["_i"]
    @sent.clear

    assert_raises(RuntimeError) { @page.dispatch_event(target: view_id, name: "refresh", data: nil) }
    assert_equal [[view_id, "end_refresh"]], invokes.map { |payload| [payload["control_id"], payload["name"]] }
  end

  def test_clearing_a_handler_removes_it_and_its_flag
    calls = []
    @page.on_scroll = ->(_e) { calls << :scroll }
    @page.on_scroll = nil
    @page.add(Ruflet.text("Body"))

    refute implicit_view.key?("on_scroll")
    @page.dispatch_event(target: implicit_view["_i"], name: "scroll", data: {})
    assert_empty calls
  end

  def test_page_target_events_and_plain_props_are_unchanged
    routes = []
    @page.on_route_change = ->(e) { routes << e.data }
    @page.padding = 12
    @page.add(Ruflet.text("Body"))

    assert_equal 12, implicit_view["padding"]
    @page.dispatch_event(target: 1, name: "route_change", data: { "route" => "/next" })
    assert_equal 1, routes.length
  end

  def test_page_on_for_view_events_sets_the_view_flag
    reached = []
    @page.on(:end_reached) { |e| reached << e.data }
    @page.on(:on_refresh) { |_e| }
    @page.add(Ruflet.text("Body"))

    assert_equal true, implicit_view["on_end_reached"]
    assert_equal true, implicit_view["on_refresh"]
    assert_empty @sent.flat_map { |_action, payload| procs_in(payload) }
    @page.dispatch_event(target: implicit_view["_i"], name: "end_reached", data: { "pixels" => 3.0 })
    assert_equal [{ "pixels" => 3.0 }], reached
  end

  def test_page_on_for_page_events_keeps_its_behavior
    routes = []
    @page.on(:route_change) { |e| routes << e.data }
    @page.on(:resize) { |_e| }
    @page.add(Ruflet.text("Body"))

    refute implicit_view.key?("on_route_change")
    refute implicit_view.key?("on_resize")
    assert_nil page_op("on_route_change")
    assert_nil page_op("on_resize")
    @page.dispatch_event(target: 1, name: "route_change", data: { "route" => "/x" })
    assert_equal 1, routes.length
  end

  def test_set_view_props_and_page_update_register_handlers
    calls = []
    @page.set_view_props(on_refresh: ->(_e) { calls << :refresh }, padding: 8)
    @page.add(Ruflet.text("Body"))
    @page.update(:page, on_scroll: ->(_e) { calls << :scroll })

    assert_empty @sent.flat_map { |_action, payload| procs_in(payload) }
    assert_equal true, implicit_view["on_refresh"]
    assert_equal true, implicit_view["on_scroll"]
    assert_equal 8, implicit_view["padding"]
    view_id = implicit_view["_i"]
    @page.dispatch_event(target: view_id, name: "refresh", data: nil)
    @page.dispatch_event(target: view_id, name: "scroll", data: {})
    assert_equal [:refresh, :scroll], calls
  end

  def test_explicit_view_events_still_go_to_the_view_control
    calls = []
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Body")], on_refresh: ->(_e) { calls << :view })
    @page.on_refresh = ->(_e) { calls << :page }
    @page.views = [view]
    @page.update
    @sent.clear

    @page.dispatch_event(target: view.wire_id, name: "refresh", data: nil)

    assert_equal [:view], calls
    assert_equal [[view.wire_id, "end_refresh"]], invokes.map { |payload| [payload["control_id"], payload["name"]] }
  end
end
