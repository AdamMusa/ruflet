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

  # move_to's destination is optional, but nil used to recurse in
  # normalize_coordinates until the stack ran out, since nil.to_h and
  # Hash#to_h both return a Hash.
  def test_move_to_without_a_destination_sends_only_what_was_given
    map = Ruflet.map([], initial_center: [0, 0])
    @page.add(map)

    map.move_to(zoom: 9, rotation: 45)
    assert_equal "move_to", @sent.last[1]["name"]
    assert_equal({ "zoom" => 9, "rotation" => 45 }, @sent.last[1]["args"])

    map.move_to(destination: { latitude: 1.5, longitude: 2.5 })
    assert_equal({ "destination" => { "latitude" => 1.5, "longitude" => 2.5 } }, @sent.last[1]["args"])

    # The client's center_on does nothing without a point.
    map.center_on(nil)
    assert_equal({}, @sent.last[1]["args"])
  end

  # Coordinates that cannot be read used to overflow the stack (a Hash
  # without both coordinates, []), or raise TypeError ([1]). They now raise
  # ArgumentError, and nothing reaches the client.
  def test_unreadable_coordinates_raise_argument_error
    map = Ruflet.map([], initial_center: [0, 0])
    @page.add(map)
    @sent.clear

    [{ "x" => 1 }, { latitude: 1 }, [], [1], Struct.new(:x).new(1)].each do |value|
      error = assert_raises(ArgumentError, value.inspect) { map.center_on(value) }
      assert_match(/map coordinates must be \[latitude, longitude\]/, error.message)
      assert_raises(ArgumentError, value.inspect) { map.move_to(destination: value) }
    end
    assert_empty @sent

    # An object whose to_h gives coordinates still works.
    map.center_on(Struct.new(:lat, :lng).new(1.5, 2.5))
    assert_equal({ "point" => { "latitude" => 1.5, "longitude" => 2.5 } }, @sent.last[1]["args"])
  end

  # The DSL helpers convert coordinates the same way, and overflowed the same.
  def test_helpers_take_unset_coordinates_and_reject_unreadable_ones
    # nil is not given: the prop is left out, as if the keyword were. A nil
    # prop would reach the client as {}, which it reads as LatLng(0, 0).
    refute_includes Ruflet.map([], initial_center: nil).to_patch, "initial_center"
    refute_includes Ruflet::UI::ControlFactory.build("map", initial_center: nil).to_patch, "initial_center"
    refute_includes Ruflet.marker(coordinates: nil, content: Ruflet.text("Pin")).to_patch, "coordinates"
    @page.add(Ruflet.map([], initial_center: nil))
    sent_map = find_wire_control(@sent.map(&:last), "Map")
    assert_equal({ "_c" => "Map", "_i" => sent_map["_i"], "layers" => [] }, sent_map)

    assert_raises(ArgumentError) { Ruflet.map([], initial_center: [1]) }
    assert_raises(ArgumentError) { Ruflet.marker(coordinates: { "x" => 1 }, content: Ruflet.text("Pin")) }
    assert_raises(ArgumentError) { Ruflet.circle_marker(coordinates: [], radius: 4) }
    # A nil point inside a polyline or polygon is a mistake too.
    assert_raises(ArgumentError) { Ruflet.polyline_marker(coordinates: [[1, 2], nil]) }
    assert_raises(ArgumentError) { Ruflet.polygon_marker(coordinates: [[1, 2], { "x" => 1 }]) }

    line = Ruflet.polyline_marker(coordinates: [[1, 2], { lat: 3, lon: 4 }])
    assert_equal [{ "latitude" => 1, "longitude" => 2 }, { "latitude" => 3, "longitude" => 4 }], line.to_patch["coordinates"]
  end

  def test_rich_attribution_family_uses_current_flet_wire_types
    image = Ruflet.image_source_attribution(Ruflet.image(src: "logo.png"), height: 24)
    text = Ruflet.text_source_attribution("OpenStreetMap", prepend_copyright: true, on_click: ->(_event) {})
    attribution = Ruflet.rich_attribution([image, text], alignment: :bottom_right)

    patch = attribution.to_patch
    assert_equal "RichAttribution", patch["_c"]
    assert_equal %w[ImageSourceAttribution TextSourceAttribution], patch["attributions"].map { |item| item["_c"] }
    assert_equal "bottom_right", patch["alignment"]
    assert text.has_handler?(:click)
    assert_equal "MapLayer", Ruflet.map_layer.to_patch["_c"]
  end

  def test_every_map_component_is_registered_with_the_control_factory
    %i[
      map map_layer tile_layer marker marker_layer circle_marker circle_layer
      polyline_marker polyline_layer polygon_marker polygon_layer
      simple_attribution rich_attribution image_source_attribution
      text_source_attribution
    ].each do |type|
      assert Ruflet::UI::ControlFactory.known_control?(type), type
    end
  end

  private

  # The first control patch of the given wire type in what the page sent.
  def find_wire_control(value, wire_type)
    case value
    when Hash
      return value if value["_c"] == wire_type

      value.each_value do |item|
        found = find_wire_control(item, wire_type)
        return found if found
      end
    when Array
      value.each do |item|
        found = find_wire_control(item, wire_type)
        return found if found
      end
    end
    nil
  end
end
