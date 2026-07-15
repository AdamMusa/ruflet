# frozen_string_literal: true

require_relative "test_helper"

class MapExtensionCompatibilityTest < Minitest::Test
  def setup
    @sent = []
    @page = Ruflet::Page.new(
      session_id: "s1",
      client_details: { "route" => "/" },
      sender: ->(action, payload) { @sent << [action, payload] }
    )
  end

  def test_map_uses_exact_extension_wire_types_and_coordinate_objects
    marker = Ruflet.marker(coordinates: [51.5, -0.09], content: Ruflet.text("Pin"))
    circle = Ruflet.circle_marker(coordinates: [51.5, -0.09], radius: 12)
    map = Ruflet.map(
      [
        Ruflet.tile_layer(url_template: "https://tiles/{z}/{x}/{y}.png"),
        Ruflet.marker_layer([marker]),
        Ruflet.circle_layer([circle]),
        Ruflet.simple_attribution(text: "Map data")
      ],
      initial_center: [51.5, -0.09],
      initial_zoom: 13
    )

    patch = map.to_patch
    assert_equal "Map", patch["_c"]
    assert_equal({ "latitude" => 51.5, "longitude" => -0.09 }, patch["initial_center"])
    assert_equal %w[TileLayer MarkerLayer CircleLayer SimpleAttribution], patch["layers"].map { |layer| layer["_c"] }
    assert_equal({ "latitude" => 51.5, "longitude" => -0.09 }, patch["layers"][1]["markers"][0]["coordinates"])
    assert_equal "CircleMarker", patch["layers"][2]["circles"][0]["_c"]
  end

  def test_map_methods_use_flet_invoke_names_and_arguments
    map = Ruflet.map([], initial_center: [0, 0])
    @page.add(map)

    map.center_on([40.7, -74.0], zoom: 12)
    assert_equal "center_on", @sent.last[1]["name"]
    assert_equal({ "point" => { "latitude" => 40.7, "longitude" => -74.0 }, "zoom" => 12 }, @sent.last[1]["args"])

    map.zoom_in
    assert_equal "zoom_in", @sent.last[1]["name"]
  end
end
