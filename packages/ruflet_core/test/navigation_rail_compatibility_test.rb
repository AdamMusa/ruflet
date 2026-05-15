# frozen_string_literal: true

require_relative "test_helper"

class RufletNavigationRailCompatibilityTest < Minitest::Test
  def test_navigation_rail_serializes_current_flet_props_and_destinations
    rail = Ruflet.navigation_rail(
      destinations: [
        Ruflet.navigation_rail_destination(icon: "favorite_border", selected_icon: "favorite", label: "First", indicator_color: "#111111"),
        Ruflet.navigation_rail_destination(icon: Ruflet.icon("search"), label: Ruflet.text("Search"), padding: 8)
      ],
      bgcolor: "#ABCDEF",
      elevation: 3,
      extended: true,
      group_alignment: -0.5,
      indicator_color: "#222222",
      indicator_shape: { border_radius: 12 },
      label_type: "none",
      leading: Ruflet.fab(icon: "add"),
      min_extended_width: 256,
      min_width: 72,
      selected_index: 1,
      selected_label_text_style: { weight: "bold" },
      trailing: Ruflet.icon("settings"),
      unselected_label_text_style: { size: 12 },
      use_indicator: true,
      on_change: ->(_event) {}
    )

    patch = rail.to_patch

    assert_equal "NavigationRail", patch["_c"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal 3, patch["elevation"]
    assert_equal true, patch["extended"]
    assert_equal(-0.5, patch["group_alignment"])
    assert_equal "#222222", patch["indicator_color"]
    assert_equal({ "border_radius" => 12 }, patch["indicator_shape"])
    assert_equal "none", patch["label_type"]
    assert_equal "FloatingActionButton", patch["leading"]["_c"]
    assert_equal 256, patch["min_extended_width"]
    assert_equal 72, patch["min_width"]
    assert_equal 1, patch["selected_index"]
    assert_equal({ "weight" => "bold" }, patch["selected_label_text_style"])
    assert_equal "Icon", patch["trailing"]["_c"]
    assert_equal({ "size" => 12 }, patch["unselected_label_text_style"])
    assert_equal true, patch["use_indicator"]
    assert_equal true, patch["on_change"]

    first, second = patch["destinations"]
    assert_equal "NavigationRailDestination", first["_c"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("favorite_border"), first["icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("favorite"), first["selected_icon"]
    assert_equal "First", first["label"]
    assert_equal "#111111", first["indicator_color"]
    assert_equal "Icon", second["icon"]["_c"]
    assert_equal "Text", second["label"]["_c"]
    assert_equal 8, second["padding"]
  end

  def test_navigationrail_alias_uses_same_control
    destinations = [
      Ruflet.navigation_rail_destination(icon: "home"),
      Ruflet.navigation_rail_destination(icon: "search")
    ]

    assert_equal "NavigationRail", Ruflet.navigationrail(destinations: destinations).to_patch["_c"]
  end

  def test_navigation_rail_requires_at_least_two_visible_destinations_like_flet
    error = assert_raises(ArgumentError) do
      Ruflet.navigation_rail(destinations: [Ruflet.navigation_rail_destination(icon: "home")])
    end

    assert_match(/destinations/, error.message)
  end

  def test_navigation_rail_rejects_out_of_range_values_like_flet
    destinations = [
      Ruflet.navigation_rail_destination(icon: "home"),
      Ruflet.navigation_rail_destination(icon: "search")
    ]

    assert_raises(IndexError) { Ruflet.navigation_rail(destinations: destinations, selected_index: -1) }
    assert_raises(IndexError) { Ruflet.navigation_rail(destinations: destinations, selected_index: 2) }
    assert_raises(ArgumentError) { Ruflet.navigation_rail(destinations: destinations, group_alignment: -1.1) }
    assert_raises(ArgumentError) { Ruflet.navigation_rail(destinations: destinations, group_alignment: 1.1) }
  end

  def test_navigation_rail_rejects_negative_numeric_values_like_flet
    destinations = [
      Ruflet.navigation_rail_destination(icon: "home"),
      Ruflet.navigation_rail_destination(icon: "search")
    ]

    %i[elevation min_extended_width min_width].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.navigation_rail(destinations: destinations, prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_navigation_rail_destination_requires_icon_like_flet
    error = assert_raises(ArgumentError) { Ruflet.navigation_rail_destination(label: "Home") }

    assert_match(/icon/, error.message)
  end

  def test_navigation_rail_change_event_updates_selected_index_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    rail = Ruflet.navigation_rail(
      destinations: [
        Ruflet.navigation_rail_destination(icon: "home"),
        Ruflet.navigation_rail_destination(icon: "search")
      ],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page.add(rail)

    page.dispatch_event(target: rail.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, rail.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
