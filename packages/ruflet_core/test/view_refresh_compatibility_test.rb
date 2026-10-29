# frozen_string_literal: true

require_relative "test_helper"

class RufletViewRefreshCompatibilityTest < Minitest::Test
  def setup
    @messages = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @messages << [action, payload] }
    )
  end

  def invokes
    @messages.select { |action, _payload| action == Ruflet::Protocol::ACTIONS[:invoke_control_method] }.map(&:last)
  end

  def test_view_serializes_page_level_scroll_keywords
    view = Ruflet.view(
      route: "/",
      controls: [Ruflet.text("Body")],
      on_refresh: ->(_e) {},
      on_end_reached: ->(_e) {},
      end_reached_threshold: 300,
      keyboard_dismiss_behavior: "onDrag",
      refresh_bgcolor: "#FFFFFF",
      refresh_color: "#0000FF",
      refresh_displacement: 50,
      refresh_timeout: { seconds: 10 },
      refresh_trigger_distance: 110
    )
    patch = view.to_patch

    assert_equal "View", patch["_c"]
    assert_equal true, patch["on_refresh"]
    assert_equal true, patch["on_end_reached"]
    assert_equal 300, patch["end_reached_threshold"]
    assert_equal "onDrag", patch["keyboard_dismiss_behavior"]
    assert_equal "#ffffff", patch["refresh_bgcolor"]
    assert_equal "#0000ff", patch["refresh_color"]
    assert_equal 50, patch["refresh_displacement"]
    assert_equal({ "seconds" => 10 }, patch["refresh_timeout"])
    assert_equal 110, patch["refresh_trigger_distance"]
    assert view.has_handler?(:refresh)
    assert view.has_handler?(:end_reached)
  end

  def test_view_refresh_runs_the_handler_then_ends_refresh_on_the_view
    calls = []
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Body")], on_refresh: ->(e) { calls << e.control })
    @page.views = [view]
    @page.update
    @messages.clear

    @page.dispatch_event(target: view.wire_id, name: "refresh", data: nil)

    assert_equal [view], calls
    assert_equal ["end_refresh"], invokes.map { |payload| payload["name"] }
    assert_equal view.wire_id, invokes.first["control_id"]
    refute_equal 1, invokes.first["control_id"], "the View, not the Page, owns the spinner"
  end

  def test_view_end_reached_is_dispatched_without_end_refresh
    received = []
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Body")], on_end_reached: ->(e) { received << e.data })
    @page.views = [view]
    @page.update
    @messages.clear

    @page.dispatch_event(target: view.wire_id, name: "end_reached", data: { "max_scroll_extent" => 0.0 })

    assert_equal [{ "max_scroll_extent" => 0.0 }], received
    assert_empty invokes
  end

  def test_view_end_refresh_method_targets_the_view
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Body")], on_refresh: ->(_e) {})
    @page.views = [view]
    @page.update
    @messages.clear

    view.end_refresh

    assert_equal [[view.wire_id, "end_refresh"]], invokes.map { |payload| [payload["control_id"], payload["name"]] }
  end
end
