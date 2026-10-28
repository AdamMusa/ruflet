# frozen_string_literal: true

require_relative "test_helper"

class RufletScrollableMethodsCompatibilityTest < Minitest::Test
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

  def test_scroll_to_invokes_the_client_method_on_the_control
    list = Ruflet.list_view([Ruflet.text("One")])
    @page.add(list)
    @messages.clear

    call_id = list.scroll_to(offset: -1, duration: 300, curve: "easeOut")

    assert_equal 1, invokes.length
    payload = invokes.first
    assert_equal call_id, payload["call_id"]
    assert_equal "scroll_to", payload["name"]
    assert_equal list.wire_id, payload["control_id"]
    assert_equal({ "offset" => -1, "duration" => 300, "curve" => "easeOut" }, payload["args"])
    assert_equal 10, payload["timeout"]
  end

  def test_scroll_to_sends_only_the_given_arguments
    list = Ruflet.list_view([Ruflet.text("One")])
    @page.add(list)
    @messages.clear

    list.scroll_to(delta: 120)
    list.scroll_to(scroll_key: "row-42", duration: 0, timeout: 3)

    assert_equal({ "delta" => 120 }, invokes[0]["args"])
    assert_equal({ "scroll_key" => "row-42", "duration" => 0 }, invokes[1]["args"])
    assert_equal 3, invokes[1]["timeout"]
  end

  def test_every_scrollable_control_exposes_scroll_to
    controls = [
      Ruflet.list_view([Ruflet.text("List")]),
      Ruflet.grid_view([Ruflet.text("Grid")]),
      Ruflet.column([Ruflet.text("Column")], scroll: "auto"),
      Ruflet.row([Ruflet.text("Row")], scroll: "auto"),
      Ruflet.reorderable_list_view([Ruflet.text("Reorder")])
    ]
    controls.each { |control| @page.add(control) }
    @messages.clear

    controls.each { |control| control.scroll_to(offset: 0) }

    assert_equal controls.map(&:wire_id), invokes.map { |payload| payload["control_id"] }
    assert_equal ["scroll_to"] * controls.length, invokes.map { |payload| payload["name"] }
    controls.each { |control| assert_includes control.class.ancestors, Ruflet::UI::Controls::ScrollableMethods }
  end

  def test_view_scroll_to_targets_the_view_not_the_page
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Body")])
    @page.views = [view]
    @page.update
    @messages.clear

    view.scroll_to(offset: 40)

    assert_equal 1, invokes.length
    assert_equal view.wire_id, invokes.first["control_id"]
    refute_equal 1, invokes.first["control_id"]
    assert_equal({ "offset" => 40 }, invokes.first["args"])
  end

  def test_scroll_to_on_unmounted_control_returns_nil_without_raising
    list = Ruflet.list_view([Ruflet.text("One")])

    assert_nil list.scroll_to(offset: -1)
    assert_empty @messages
  end

  def test_scroll_to_on_result_receives_client_result
    list = Ruflet.list_view([Ruflet.text("One")])
    @page.add(list)
    results = []

    call_id = list.scroll_to(offset: 10, timeout: nil, on_result: ->(result, error) { results << [result, error] })
    @page.handle_invoke_method_result("call_id" => call_id, "result" => nil, "error" => nil)

    assert_equal [[nil, nil]], results
  end
end
