# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class MapControl < Ruflet::Control
          TYPE = "map".freeze
          WIRE = "Map".freeze
          # Map accepts the extension's evolving property surface through
          # **props. An explicit empty schema keeps mruby from mistaking the
          # keyrest parameter itself for a property named `props`.
          KEYWORDS = [].freeze

          def initialize(id: nil, **props)
            mapped = props.dup
            mapped[:initial_center] = normalize_coordinates(mapped[:initial_center]) if mapped.key?(:initial_center)
            super(type: TYPE, id: id, **mapped)
          end

          def rotate_from(degree, **options)
            invoke_map("rotate_from", options.merge(degree: degree))
          end

          def reset_rotation(**options)
            invoke_map("reset_rotation", options)
          end

          def zoom_in(**options)
            invoke_map("zoom_in", options)
          end

          def zoom_out(**options)
            invoke_map("zoom_out", options)
          end

          def zoom_to(zoom, **options)
            invoke_map("zoom_to", options.merge(zoom: zoom))
          end

          def move_to(destination: nil, zoom: nil, rotation: nil, offset: nil, **options)
            invoke_map(
              "move_to",
              options.merge(
                destination: normalize_coordinates(destination),
                zoom: zoom,
                rotation: rotation,
                offset: offset
              )
            )
          end

          def center_on(point, zoom: nil, **options)
            invoke_map("center_on", options.merge(point: normalize_coordinates(point), zoom: zoom))
          end

          private

          def invoke_map(name, options)
            timeout = options.delete(:timeout) || 10
            on_result = options.delete(:on_result)
            args = options.each_with_object({}) do |(key, value), result|
              next if value.nil?

              wire_key = case key.to_s
                         when "animation_curve" then "curve"
                         when "animation_duration" then "duration"
                         else key.to_s
                         end
              result[wire_key] = normalize_map_value(value)
            end
            runtime_page&.invoke(self, name, args: args, timeout: timeout, on_result: on_result)
          end

          def normalize_coordinates(value)
            case value
            when Array
              return { "latitude" => value[0], "longitude" => value[1] } if value.length >= 2
            when Hash
              latitude = value["latitude"] || value[:latitude] || value["lat"] || value[:lat]
              longitude = value["longitude"] || value[:longitude] || value["lon"] || value[:lon] || value["lng"] || value[:lng]
              return { "latitude" => latitude, "longitude" => longitude } unless latitude.nil? || longitude.nil?
            end
            value.respond_to?(:to_h) ? normalize_coordinates(value.to_h) : value
          end

          def normalize_map_value(value)
            case value
            when Array then value.map { |item| normalize_map_value(item) }
            when Hash then value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_map_value(item) unless item.nil? }
            when Symbol then value.to_s
            else value.respond_to?(:to_h) ? normalize_map_value(value.to_h) : value
            end
          end
        end

        class MapExtensionControl < Ruflet::Control
          KEYWORDS = [].freeze

          def initialize(type:, id: nil, **props)
            compact = {}
            props.each { |key, value| compact[key] = value unless value.nil? }
            super(type: type, id: id, **compact)
          end
        end

        class MapLayerControl < MapExtensionControl
          WIRE = "MapLayer".freeze
          def initialize(id: nil, **props) = super(type: "map_layer", id: id, **props)
        end

        class TileLayerControl < MapExtensionControl
          WIRE = "TileLayer".freeze
          def initialize(id: nil, **props) = super(type: "tile_layer", id: id, **props)
        end

        class MarkerControl < MapExtensionControl
          WIRE = "Marker".freeze
          def initialize(id: nil, **props) = super(type: "marker", id: id, **props)
        end

        class MarkerLayerControl < MapExtensionControl
          WIRE = "MarkerLayer".freeze
          def initialize(id: nil, **props) = super(type: "marker_layer", id: id, **props)
        end

        class CircleMarkerControl < MapExtensionControl
          WIRE = "CircleMarker".freeze
          def initialize(id: nil, **props) = super(type: "circle_marker", id: id, **props)
        end

        class CircleLayerControl < MapExtensionControl
          WIRE = "CircleLayer".freeze
          def initialize(id: nil, **props) = super(type: "circle_layer", id: id, **props)
        end

        class PolylineMarkerControl < MapExtensionControl
          WIRE = "PolylineMarker".freeze
          def initialize(id: nil, **props) = super(type: "polyline_marker", id: id, **props)
        end

        class PolylineLayerControl < MapExtensionControl
          WIRE = "PolylineLayer".freeze
          def initialize(id: nil, **props) = super(type: "polyline_layer", id: id, **props)
        end

        class PolygonMarkerControl < MapExtensionControl
          WIRE = "PolygonMarker".freeze
          def initialize(id: nil, **props) = super(type: "polygon_marker", id: id, **props)
        end

        class PolygonLayerControl < MapExtensionControl
          WIRE = "PolygonLayer".freeze
          def initialize(id: nil, **props) = super(type: "polygon_layer", id: id, **props)
        end

        class SimpleAttributionControl < MapExtensionControl
          WIRE = "SimpleAttribution".freeze
          def initialize(id: nil, **props) = super(type: "simple_attribution", id: id, **props)
        end

        class RichAttributionControl < MapExtensionControl
          WIRE = "RichAttribution".freeze
          def initialize(id: nil, **props) = super(type: "rich_attribution", id: id, **props)
        end

        class ImageSourceAttributionControl < MapExtensionControl
          WIRE = "ImageSourceAttribution".freeze
          def initialize(id: nil, **props) = super(type: "image_source_attribution", id: id, **props)
        end

        class TextSourceAttributionControl < MapExtensionControl
          WIRE = "TextSourceAttribution".freeze
          def initialize(id: nil, **props) = super(type: "text_source_attribution", id: id, **props)
        end
      end
    end
  end
end
