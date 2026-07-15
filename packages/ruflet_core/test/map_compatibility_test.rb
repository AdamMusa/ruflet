# frozen_string_literal: true

require_relative "test_helper"

class MapCompatibilityTest < Minitest::Test
  def test_map_serializes_flet_layers_and_events
    map = Ruflet.map(
      layers: [
        Ruflet.tile_layer(
          url_template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          user_agent_package_name: "com.example.ruflet",
          max_zoom: 19
        ),
        Ruflet.marker_layer(
          markers: [
            Ruflet.marker(
              coordinates: [51.5, -0.09],
              content: Ruflet.icon(icon: "location_on"),
              width: 40,
              height: 40,
              rotate: true
            )
          ]
        ),
        Ruflet.circle_layer(
          circles: [
            Ruflet.circle_marker(
              coordinates: { latitude: 51.5, longitude: -0.09 },
              radius: 250,
              color: "#3366ff33",
              border_color: "#3366ff",
              border_stroke_width: 2
            )
          ]
        ),
        Ruflet.polyline_layer(
          polylines: [
            Ruflet.polyline_marker(
              coordinates: [[51.5, -0.09], [51.51, -0.1]],
              color: "#ff0000",
              stroke_width: 4
            )
          ]
        ),
        Ruflet.polygon_layer(
          polygons: [
            Ruflet.polygon_marker(
              coordinates: [[51.5, -0.09], [51.51, -0.1], [51.49, -0.1]],
              color: "#00ff0044",
              border_color: "#00aa00",
              border_stroke_width: 2
            )
          ]
        )
      ],
      initial_center: [51.5, -0.09],
      initial_zoom: 13,
      min_zoom: 2,
      max_zoom: 18,
      interaction_configuration: { flags: "all" },
      on_tap: ->(_event) {},
      on_position_change: ->(_event) {}
    )

    patch = map.to_patch

    assert_equal "Map", patch["_c"]
    assert_equal({ "latitude" => 51.5, "longitude" => -0.09 }, patch["initial_center"])
    assert_equal 13, patch["initial_zoom"]
    assert_equal 2, patch["min_zoom"]
    assert_equal 18, patch["max_zoom"]
    assert_equal({ "flags" => "all" }, patch["interaction_configuration"])
    assert_equal true, patch["on_tap"]
    assert_equal true, patch["on_position_change"]

    layers = patch.fetch("layers")
    assert_equal %w[TileLayer MarkerLayer CircleLayer PolylineLayer PolygonLayer], layers.map { |layer| layer["_c"] }
    assert_equal "https://tile.openstreetmap.org/{z}/{x}/{y}.png", layers[0]["url_template"]
    assert_equal "com.example.ruflet", layers[0]["user_agent_package_name"]
    assert_equal "Marker", layers[1].fetch("markers").first["_c"]
    assert_equal({ "latitude" => 51.5, "longitude" => -0.09 }, layers[1].fetch("markers").first["coordinates"])
    assert_equal "CircleMarker", layers[2].fetch("circles").first["_c"]
    assert_equal "PolylineMarker", layers[3].fetch("polylines").first["_c"]
    assert_equal(
      [
        { "latitude" => 51.5, "longitude" => -0.09 },
        { "latitude" => 51.51, "longitude" => -0.1 }
      ],
      layers[3].fetch("polylines").first["coordinates"]
    )
    assert_equal "PolygonMarker", layers[4].fetch("polygons").first["_c"]
  end

  def test_map_attribution_and_rich_attribution_serialization
    tile_layer = Ruflet.tile_layer(
      url_template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
      attribution: Ruflet.simple_attribution(
        text: "OpenStreetMap contributors",
        alignment: "bottom_right",
        on_click: ->(_event) {}
      ),
      additional_options: { retina: true }
    )

    patch = tile_layer.to_patch

    assert_equal "TileLayer", patch["_c"]
    assert_equal({ "retina" => true }, patch["additional_options"])
    assert_equal "SimpleAttribution", patch.fetch("attribution")["_c"]
    assert_equal "OpenStreetMap contributors", patch.fetch("attribution")["text"]
    assert_equal true, patch.fetch("attribution")["on_click"]
  end

  def test_map_methods_use_flet_payload_shape
    calls = []
    page = Object.new
    page.define_singleton_method(:invoke) do |control, method_name, args: nil, timeout: 10, on_result: nil|
      calls << [control, method_name, args, timeout, on_result]
    end

    map = Ruflet.map
    map.runtime_page = page
    callback = ->(_result, _error) {}

    map.center_on([51.5, -0.09], zoom: 12, timeout: 3, on_result: callback)
    map.move_to([52.0, -0.12], zoom: 14, rotation: 10, offset: { x: 1, y: 2 })
    map.zoom_to(5, duration: 250, curve: "ease_in", cancel_ongoing_animations: true)
    map.zoom_in(delta: 2)
    map.zoom_out(delta: 1)
    map.rotate_from(45)
    map.reset_rotation

    assert_equal(
      [
        [map, "center_on", { "point" => { "latitude" => 51.5, "longitude" => -0.09 }, "zoom" => 12 }, 3, callback],
        [map, "move_to", { "destination" => { "latitude" => 52.0, "longitude" => -0.12 }, "zoom" => 14, "rotation" => 10, "offset" => { "x" => 1, "y" => 2 } }, 10, nil],
        [map, "zoom_to", { "zoom" => 5, "duration" => 250, "curve" => "ease_in", "cancel_ongoing_animations" => true }, 10, nil],
        [map, "zoom_in", { "delta" => 2 }, 10, nil],
        [map, "zoom_out", { "delta" => 1 }, 10, nil],
        [map, "rotate_from", { "degree" => 45 }, 10, nil],
        [map, "reset_rotation", nil, 10, nil]
      ],
      calls
    )
  end
end
