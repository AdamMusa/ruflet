# frozen_string_literal: true

require_relative "test_helper"

class RufletCupertinoNavigationBarCompatibilityTest < Minitest::Test
  def test_cupertino_navigation_bar_serializes_current_flet_props_and_destinations
    bar = Ruflet.cupertino_navigation_bar(
      destinations: [
        Ruflet.navigation_bar_destination(icon: "home", selected_icon: "home_filled", label: "Home", bgcolor: "#111111"),
        Ruflet.navigation_bar_destination(icon: Ruflet.icon("search"), label: "Search")
      ],
      active_color: "#ABCDEF",
      bgcolor: "#112233",
      border: { top: { width: 1 } },
      icon_size: 28,
      inactive_color: "#445566",
      selected_index: 1,
      on_change: ->(_event) {}
    )

    patch = bar.to_patch

    assert_equal "CupertinoNavigationBar", patch["_c"]
    assert_equal "#abcdef", patch["active_color"]
    assert_equal "#112233", patch["bgcolor"]
    assert_equal({ "top" => { "width" => 1 } }, patch["border"])
    assert_equal 28, patch["icon_size"]
    assert_equal "#445566", patch["inactive_color"]
    assert_equal 1, patch["selected_index"]
    assert_equal true, patch["on_change"]

    first, second = patch["destinations"]
    assert_equal "NavigationBarDestination", first["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home"), first["icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home_filled"), first["selected_icon"]
    assert_equal "Home", first["label"]
    assert_equal "#111111", first["bgcolor"]
    assert_equal "Icon", second["icon"]["_c"]
  end

  def test_compact_alias_uses_same_control
    destinations = [
      Ruflet.navigation_bar_destination(icon: "home"),
      Ruflet.navigation_bar_destination(icon: "search")
    ]

    assert_equal "CupertinoNavigationBar", Ruflet.cupertinonavigationbar(destinations: destinations).to_patch["_c"]
  end

  def test_cupertino_navigation_bar_defaults_match_flet
    bar = Ruflet.cupertino_navigation_bar

    assert_equal 30, bar.props["icon_size"]
    assert_equal 0, bar.props["selected_index"]
  end

  def test_cupertino_navigation_bar_requires_at_least_two_visible_destinations_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.cupertino_navigation_bar(destinations: [Ruflet.navigation_bar_destination(icon: "home")])
    end

    assert_match(/destinations/, error.message)
  end

  def test_cupertino_navigation_bar_rejects_selected_index_out_of_range_like_flet
    destinations = [
      Ruflet.navigation_bar_destination(icon: "home"),
      Ruflet.navigation_bar_destination(icon: "search")
    ]

    assert_raises(IndexError) { Ruflet.cupertino_navigation_bar(destinations: destinations, selected_index: -1) }
    assert_raises(IndexError) { Ruflet.cupertino_navigation_bar(destinations: destinations, selected_index: 2) }
  end

  def test_cupertino_navigation_bar_change_event_updates_selected_index_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    bar = Ruflet.cupertino_navigation_bar(
      destinations: [
        Ruflet.navigation_bar_destination(icon: "home"),
        Ruflet.navigation_bar_destination(icon: "search")
      ],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page.add(Ruflet.text("Body"), navigation_bar: bar)

    page.dispatch_event(target: bar.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, bar.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
