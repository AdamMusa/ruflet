# frozen_string_literal: true

require_relative "test_helper"

class RufletNavigationBarCompatibilityTest < Minitest::Test
  def test_navigation_bar_serializes_current_flet_props_and_destinations
    bar = Ruflet.navigation_bar(
      destinations: [
        Ruflet.navigation_bar_destination(icon: "home", selected_icon: "home_filled", label: "Home", bgcolor: "#111111"),
        Ruflet.navigation_bar_destination(icon: Ruflet.icon("search"), label: "Search")
      ],
      adaptive: true,
      animation_duration: 200,
      bgcolor: "#ABCDEF",
      border: { top: { width: 1 } },
      elevation: 3,
      indicator_color: "#222222",
      indicator_shape: { border_radius: 12 },
      label_behavior: "alwaysShow",
      label_padding: { top: 4 },
      overlay_color: { pressed: "#333333" },
      selected_index: 1,
      shadow_color: "#444444",
      surface_tint_color: "#555555",
      on_change: ->(_event) {}
    )

    patch = bar.to_patch

    assert_equal "NavigationBar", patch["_c"]
    assert_equal true, patch["adaptive"]
    assert_equal 200, patch["animation_duration"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal({ "top" => { "width" => 1 } }, patch["border"])
    assert_equal 3, patch["elevation"]
    assert_equal "#222222", patch["indicator_color"]
    assert_equal({ "border_radius" => 12 }, patch["indicator_shape"])
    assert_equal "alwaysShow", patch["label_behavior"]
    assert_equal({ "top" => 4 }, patch["label_padding"])
    assert_equal({ "pressed" => "#333333" }, patch["overlay_color"])
    assert_equal 1, patch["selected_index"]
    assert_equal "#444444", patch["shadow_color"]
    assert_equal "#555555", patch["surface_tint_color"]
    assert_equal true, patch["on_change"]

    first, second = patch["destinations"]
    assert_equal "NavigationBarDestination", first["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home"), first["icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home_filled"), first["selected_icon"]
    assert_equal "Home", first["label"]
    assert_equal "#111111", first["bgcolor"]
    assert_equal "Icon", second["icon"]["_c"]
  end

  def test_navigation_bar_requires_at_least_two_visible_destinations_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.navigation_bar(destinations: [Ruflet.navigation_bar_destination(icon: "home")])
    end

    assert_match(/destinations/, error.message)
  end

  def test_navigation_bar_rejects_selected_index_out_of_range_like_flet
    destinations = [
      Ruflet.navigation_bar_destination(icon: "home"),
      Ruflet.navigation_bar_destination(icon: "search")
    ]

    assert_raises(IndexError) { Ruflet.navigation_bar(destinations: destinations, selected_index: -1) }
    assert_raises(IndexError) { Ruflet.navigation_bar(destinations: destinations, selected_index: 2) }
  end

  def test_navigation_bar_destination_requires_icon_like_flet
    error = assert_raises(ArgumentError) { Ruflet.navigation_bar_destination(label: "Home") }

    assert_match(/icon/, error.message)
  end

  def test_navigation_bar_change_event_updates_selected_index_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    bar = Ruflet.navigation_bar(
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
