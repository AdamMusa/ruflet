# frozen_string_literal: true

require_relative "test_helper"

class RufletNavigationDrawerCompatibilityTest < Minitest::Test
  def test_navigation_drawer_serializes_current_flet_props_and_children
    children = [
      Ruflet.container(content: Ruflet.text("Header")),
      Ruflet.navigation_drawer_destination(icon: "home", selected_icon: "home_filled", label: "Home", bgcolor: "#111111"),
      Ruflet.divider(thickness: 2),
      Ruflet.navigation_drawer_destination(icon: Ruflet.icon("search"), label: "Search")
    ]
    drawer = Ruflet.navigation_drawer(
      children,
      adaptive: true,
      bgcolor: "#ABCDEF",
      elevation: 4,
      indicator_color: "#222222",
      indicator_shape: { border_radius: 12 },
      selected_index: 1,
      shadow_color: "#333333",
      surface_tint_color: "#444444",
      tile_padding: { left: 12, right: 12 },
      width: 304,
      on_change: ->(_event) {},
      on_dismiss: ->(_event) {}
    )

    patch = drawer.to_patch

    assert_equal "NavigationDrawer", patch["_c"]
    assert_equal children, drawer.children
    refute drawer.props.key?("controls")
    assert_equal true, patch["adaptive"]
    assert_equal "#abcdef", patch["bgcolor"]
    assert_equal 4, patch["elevation"]
    assert_equal "#222222", patch["indicator_color"]
    assert_equal({ "border_radius" => 12 }, patch["indicator_shape"])
    assert_equal 1, patch["selected_index"]
    assert_equal "#333333", patch["shadow_color"]
    assert_equal "#444444", patch["surface_tint_color"]
    assert_equal({ "left" => 12, "right" => 12 }, patch["tile_padding"])
    assert_equal 304, patch["width"]
    assert_equal true, patch["on_change"]
    assert_equal true, patch["on_dismiss"]

    assert_equal ["Container", "NavigationDrawerDestination", "Divider", "NavigationDrawerDestination"], patch["controls"].map { |control| control["_c"] }
    first_destination = patch["controls"][1]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home"), first_destination["icon"]
    assert_equal Ruflet::MaterialIconLookup.codepoint_for("home_filled"), first_destination["selected_icon"]
    assert_equal "Home", first_destination["label"]
    assert_equal "#111111", first_destination["bgcolor"]
    assert_equal "Icon", patch["controls"][3]["icon"]["_c"]
  end

  def test_navigation_drawer_accepts_children_keyword_and_controls_alias_without_storing_controls_prop
    first = Ruflet.navigation_drawer_destination(icon: "home")
    second = Ruflet.navigation_drawer_destination(icon: "search")

    with_children = Ruflet.navigation_drawer(children: [first])
    with_controls_alias = Ruflet.navigation_drawer(controls: [second])

    assert_equal [first], with_children.children
    assert_equal [second], with_controls_alias.children
    refute with_children.props.key?("controls")
    refute with_controls_alias.props.key?("controls")
  end

  def test_navigation_drawer_defaults_match_flet
    drawer = Ruflet.navigation_drawer

    assert_equal [], drawer.children
    refute drawer.props.key?("controls")
    assert_equal 0, drawer.props["selected_index"]
  end

  def test_navigationdrawer_alias_uses_same_control
    controls = [
      Ruflet.navigation_drawer_destination(icon: "home"),
      Ruflet.navigation_drawer_destination(icon: "search")
    ]

    assert_equal "NavigationDrawer", Ruflet.navigationdrawer(controls).to_patch["_c"]
  end

  def test_navigation_drawer_destination_requires_icon_like_flet
    error = assert_raises(ArgumentError) { Ruflet.navigation_drawer_destination(label: "Home") }

    assert_match(/icon/, error.message)
  end

  def test_navigation_drawer_rejects_negative_elevation_and_width_like_flet
    controls = [
      Ruflet.navigation_drawer_destination(icon: "home"),
      Ruflet.navigation_drawer_destination(icon: "search")
    ]

    %i[elevation width].each do |prop|
      error = assert_raises(ArgumentError) { Ruflet.navigation_drawer(controls, prop => -1) }

      assert_match(/#{prop}/, error.message)
    end
  end

  def test_navigation_drawer_change_event_updates_selected_index_before_handler
    page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(_action, _payload) {}
    )

    observed = []
    drawer = Ruflet.navigation_drawer(
      [
        Ruflet.navigation_drawer_destination(icon: "home"),
        Ruflet.navigation_drawer_destination(icon: "search")
      ],
      selected_index: 0,
      on_change: ->(event) { observed << [event.value, event.control.props["selected_index"]] }
    )
    page.add(drawer)

    page.dispatch_event(target: drawer.wire_id, name: "change", data: { "value" => 1 })

    assert_equal 1, drawer.props["selected_index"]
    assert_equal [[1, 1]], observed
  end
end
