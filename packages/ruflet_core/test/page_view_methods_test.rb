# frozen_string_literal: true

require_relative "test_helper"

# Page#scroll_to and the page drawer methods are View methods on the client
# (Flutter's View answers show_drawer/close_drawer/... and its ScrollableControl
# answers scroll_to). The Page control (id 1) does not know them. Like Flet,
# scroll_to goes to the root view and the drawer methods to the top view.
class RufletPageViewMethodsTest < Minitest::Test
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

  def implicit_view_id
    @sent.reverse_each do |_action, payload|
      ops = payload.is_a?(Hash) && payload["patch"]
      next unless ops.is_a?(Array)

      views = ops.find { |op| op.is_a?(Array) && op[2] == "views" }
      return views[3].first["_i"] if views
    end
    flunk "no views patch sent"
  end

  def test_implicit_page_routes_view_methods_to_the_page_view
    @page.drawer = Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "home")])
    @page.end_drawer = Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "search")])
    @page.add(Ruflet.text("Body"))
    view_id = implicit_view_id
    @sent.clear

    @page.scroll_to(offset: -1)
    @page.show_drawer
    @page.close_drawer
    @page.show_end_drawer
    @page.close_end_drawer

    assert_equal %w[scroll_to show_drawer close_drawer show_end_drawer close_end_drawer], invokes.map { |payload| payload["name"] }
    assert_equal [view_id] * 5, invokes.map { |payload| payload["control_id"] }
    refute_includes invokes.map { |payload| payload["control_id"] }, 1
    assert_equal({ "offset" => -1, "delta" => nil, "scroll_key" => nil, "duration" => nil, "curve" => nil }, invokes.first["args"])
  end

  def test_scroll_to_targets_the_root_view_and_drawers_the_top_view
    root = Ruflet.view(route: "/", controls: [Ruflet.text("Home")])
    top = Ruflet.view(
      route: "/settings",
      controls: [Ruflet.text("Settings")],
      drawer: Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "home")]),
      end_drawer: Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "search")])
    )
    @page.views = [root, top]
    @page.update
    @sent.clear

    @page.scroll_to(delta: 50)
    @page.show_drawer
    @page.close_drawer
    @page.show_end_drawer
    @page.close_end_drawer

    assert_equal [root.wire_id, top.wire_id, top.wire_id, top.wire_id, top.wire_id], invokes.map { |payload| payload["control_id"] }
    refute_nil root.wire_id
    refute_equal root.wire_id, top.wire_id
  end

  def test_view_methods_work_before_explicit_views_are_registered
    view = Ruflet.view(route: "/", controls: [Ruflet.text("Home")])
    @page.views = [view]

    @page.scroll_to(offset: 0)

    refute_nil view.wire_id
    assert_equal view.wire_id, invokes.last["control_id"]
  end

  def test_drawer_methods_require_a_drawer_on_the_top_view
    assert_match(/No drawer defined/, assert_raises(ArgumentError) { @page.show_drawer }.message)
    assert_match(/No end_drawer defined/, assert_raises(ArgumentError) { @page.show_end_drawer }.message)

    @page.views = [Ruflet.view(route: "/", controls: [Ruflet.text("Home")])]
    assert_raises(ArgumentError) { @page.show_drawer }

    @page.views = [Ruflet.view(route: "/", drawer: Ruflet.navigation_drawer([Ruflet.navigation_drawer_destination(icon: "home")]))]
    @page.show_drawer
    assert_equal "show_drawer", invokes.last["name"]
  end

  def test_page_level_methods_still_target_the_page
    @page.add(Ruflet.text("Body"))
    @sent.clear

    @page.invoke(:page, "take_screenshot")

    assert_equal 1, invokes.last["control_id"]
  end
end
