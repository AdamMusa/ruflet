# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        module MapValueNormalizer
          private

          def normalize_map_coordinate(value)
            case value
            when Array
              if value.length == 2 && value.all? { |item| item.is_a?(Numeric) }
                { "latitude" => value[0], "longitude" => value[1] }
              else
                value.map { |item| normalize_map_coordinate(item) }
              end
            when Hash
              value.transform_keys(&:to_s).each_with_object({}) do |(key, item), result|
                result[key] = normalize_map_coordinate(item)
              end
            else
              value.respond_to?(:to_h) ? normalize_map_coordinate(value.to_h) : value
            end
          end
        end

        class MapControl < Ruflet::Control
          include MapValueNormalizer

          TYPE = "map".freeze
          WIRE = "Map".freeze

          def initialize(id: nil, layers: nil, initial_center: nil, initial_zoom: nil, min_zoom: nil, max_zoom: nil, interaction_configuration: nil, keep_alive: nil, bgcolor: nil, data: nil, expand: nil, height: nil, key: nil, visible: nil, width: nil, on_init: nil, on_long_press: nil, on_position_change: nil, on_secondary_tap: nil, on_tap: nil)
            props = {}
            props[:layers] = layers unless layers.nil?
            props[:initial_center] = normalize_map_coordinate(initial_center) unless initial_center.nil?
            props[:initial_zoom] = initial_zoom unless initial_zoom.nil?
            props[:min_zoom] = min_zoom unless min_zoom.nil?
            props[:max_zoom] = max_zoom unless max_zoom.nil?
            props[:interaction_configuration] = interaction_configuration unless interaction_configuration.nil?
            props[:keep_alive] = keep_alive unless keep_alive.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:data] = data unless data.nil?
            props[:expand] = expand unless expand.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_init] = on_init unless on_init.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_position_change] = on_position_change unless on_position_change.nil?
            props[:on_secondary_tap] = on_secondary_tap unless on_secondary_tap.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            super(type: TYPE, id: id, **props)
          end

          def center_on(point = nil, coordinates: nil, zoom: nil, duration: nil, curve: nil, cancel_ongoing_animations: nil, timeout: 10, on_result: nil)
            point ||= coordinates
            invoke_map(
              "center_on",
              args: compact_args(
                "point" => normalize_map_coordinate(point),
                "zoom" => zoom,
                "duration" => duration,
                "curve" => curve,
                "cancel_ongoing_animations" => cancel_ongoing_animations
              ),
              timeout: timeout,
              on_result: on_result
            )
          end

          def move_to(destination = nil, coordinates: nil, zoom: nil, rotation: nil, offset: nil, duration: nil, curve: nil, cancel_ongoing_animations: nil, timeout: 10, on_result: nil)
            destination ||= coordinates
            invoke_map(
              "move_to",
              args: compact_args(
                "destination" => normalize_map_coordinate(destination),
                "zoom" => zoom,
                "rotation" => rotation,
                "offset" => offset,
                "duration" => duration,
                "curve" => curve,
                "cancel_ongoing_animations" => cancel_ongoing_animations
              ),
              timeout: timeout,
              on_result: on_result
            )
          end

          def zoom_to(zoom, duration: nil, curve: nil, cancel_ongoing_animations: nil, timeout: 10, on_result: nil)
            invoke_map(
              "zoom_to",
              args: compact_args(
                "zoom" => zoom,
                "duration" => duration,
                "curve" => curve,
                "cancel_ongoing_animations" => cancel_ongoing_animations
              ),
              timeout: timeout,
              on_result: on_result
            )
          end

          def zoom_in(delta: nil, timeout: 10, on_result: nil)
            invoke_map("zoom_in", args: compact_args("delta" => delta), timeout: timeout, on_result: on_result)
          end

          def zoom_out(delta: nil, timeout: 10, on_result: nil)
            invoke_map("zoom_out", args: compact_args("delta" => delta), timeout: timeout, on_result: on_result)
          end

          def rotate_from(degree, timeout: 10, on_result: nil)
            invoke_map("rotate_from", args: { "degree" => degree }, timeout: timeout, on_result: on_result)
          end

          def reset_rotation(timeout: 10, on_result: nil)
            invoke_map("reset_rotation", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_map(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def compact_args(hash)
            hash.each_with_object({}) do |(key, value), result|
              result[key] = normalize_service_value(value) unless value.nil?
            end
          end

          def normalize_service_value(value)
            case value
            when Array
              value.map { |item| normalize_service_value(item) }
            when Hash
              value.transform_keys(&:to_s).each_with_object({}) do |(key, item), result|
                result[key] = normalize_service_value(item) unless item.nil?
              end
            else
              value.respond_to?(:to_h) ? normalize_service_value(value.to_h) : value
            end
          end
        end

        class TileLayerControl < Ruflet::Control
          TYPE = "tilelayer".freeze
          WIRE = "TileLayer".freeze

          def initialize(id: nil, url_template: nil, fallback_url: nil, subdomains: nil, additional_options: nil, attribution: nil, max_zoom: nil, min_zoom: nil, retina_mode: nil, tile_bounds: nil, tile_size: nil, user_agent_package_name: nil, visible: nil)
            props = {}
            props[:url_template] = url_template unless url_template.nil?
            props[:fallback_url] = fallback_url unless fallback_url.nil?
            props[:subdomains] = subdomains unless subdomains.nil?
            props[:additional_options] = additional_options unless additional_options.nil?
            props[:attribution] = attribution unless attribution.nil?
            props[:max_zoom] = max_zoom unless max_zoom.nil?
            props[:min_zoom] = min_zoom unless min_zoom.nil?
            props[:retina_mode] = retina_mode unless retina_mode.nil?
            props[:tile_bounds] = tile_bounds unless tile_bounds.nil?
            props[:tile_size] = tile_size unless tile_size.nil?
            props[:user_agent_package_name] = user_agent_package_name unless user_agent_package_name.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class MarkerLayerControl < Ruflet::Control
          TYPE = "markerlayer".freeze
          WIRE = "MarkerLayer".freeze

          def initialize(id: nil, markers: nil, rotate: nil, visible: nil)
            props = {}
            props[:markers] = markers unless markers.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class MarkerControl < Ruflet::Control
          include MapValueNormalizer

          TYPE = "marker".freeze
          WIRE = "Marker".freeze

          def initialize(id: nil, coordinates: nil, content: nil, height: nil, rotate: nil, width: nil, alignment: nil)
            props = {}
            props[:coordinates] = normalize_map_coordinate(coordinates) unless coordinates.nil?
            props[:content] = content unless content.nil?
            props[:height] = height unless height.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:width] = width unless width.nil?
            props[:alignment] = alignment unless alignment.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class CircleLayerControl < Ruflet::Control
          TYPE = "circlelayer".freeze
          WIRE = "CircleLayer".freeze

          def initialize(id: nil, circles: nil, visible: nil)
            props = {}
            props[:circles] = circles unless circles.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class CircleMarkerControl < Ruflet::Control
          include MapValueNormalizer

          TYPE = "circlemarker".freeze
          WIRE = "CircleMarker".freeze

          def initialize(id: nil, coordinates: nil, radius: nil, color: nil, border_color: nil, border_stroke_width: nil, use_radius_in_meter: nil)
            props = {}
            props[:coordinates] = normalize_map_coordinate(coordinates) unless coordinates.nil?
            props[:radius] = radius unless radius.nil?
            props[:color] = color unless color.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:border_stroke_width] = border_stroke_width unless border_stroke_width.nil?
            props[:use_radius_in_meter] = use_radius_in_meter unless use_radius_in_meter.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PolylineLayerControl < Ruflet::Control
          TYPE = "polylinelayer".freeze
          WIRE = "PolylineLayer".freeze

          def initialize(id: nil, polylines: nil, visible: nil)
            props = {}
            props[:polylines] = polylines unless polylines.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PolylineMarkerControl < Ruflet::Control
          include MapValueNormalizer

          TYPE = "polylinemarker".freeze
          WIRE = "PolylineMarker".freeze

          def initialize(id: nil, coordinates: nil, color: nil, stroke_width: nil, border_color: nil, border_stroke_width: nil, gradient_colors: nil, stroke_cap: nil, stroke_join: nil)
            props = {}
            props[:coordinates] = normalize_map_coordinate(coordinates) unless coordinates.nil?
            props[:color] = color unless color.nil?
            props[:stroke_width] = stroke_width unless stroke_width.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:border_stroke_width] = border_stroke_width unless border_stroke_width.nil?
            props[:gradient_colors] = gradient_colors unless gradient_colors.nil?
            props[:stroke_cap] = stroke_cap unless stroke_cap.nil?
            props[:stroke_join] = stroke_join unless stroke_join.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PolygonLayerControl < Ruflet::Control
          TYPE = "polygonlayer".freeze
          WIRE = "PolygonLayer".freeze

          def initialize(id: nil, polygons: nil, visible: nil)
            props = {}
            props[:polygons] = polygons unless polygons.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class PolygonMarkerControl < Ruflet::Control
          include MapValueNormalizer

          TYPE = "polygonmarker".freeze
          WIRE = "PolygonMarker".freeze

          def initialize(id: nil, coordinates: nil, color: nil, border_color: nil, border_stroke_width: nil, disable_holes_border: nil, label: nil)
            props = {}
            props[:coordinates] = normalize_map_coordinate(coordinates) unless coordinates.nil?
            props[:color] = color unless color.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:border_stroke_width] = border_stroke_width unless border_stroke_width.nil?
            props[:disable_holes_border] = disable_holes_border unless disable_holes_border.nil?
            props[:label] = label unless label.nil?
            super(type: TYPE, id: id, **props)
          end
        end

        class SimpleAttributionControl < Ruflet::Control
          TYPE = "simpleattribution".freeze
          WIRE = "SimpleAttribution".freeze

          def initialize(id: nil, text: nil, alignment: nil, bgcolor: nil, text_style: nil, url: nil, on_click: nil)
            props = {}
            props[:text] = text unless text.nil?
            props[:alignment] = alignment unless alignment.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:text_style] = text_style unless text_style.nil?
            props[:url] = url unless url.nil?
            props[:on_click] = on_click unless on_click.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
