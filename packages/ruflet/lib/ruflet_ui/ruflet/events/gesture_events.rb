# frozen_string_literal: true

require_relative "../types/geometry"

module Ruflet
  module Events
    class BasePayload
      def self.pick(data, short, long)
        return nil unless data.is_a?(Hash)

        data[short] || data[short.to_sym] || data[long] || data[long.to_sym]
      end

      def self.offset(data, short, long)
        UI::Types::Offset.from_wire(pick(data, short, long))
      end

      def self.duration(data, short, long)
        UI::Types::Duration.from_wire(pick(data, short, long))
      end

      def self.stringify_keys(data)
        return {} unless data.is_a?(Hash)

        data.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end
    end

    class GenericEvent < BasePayload
      attr_reader :raw, :value

      def initialize(raw:, value: nil)
        @raw = raw
        @value = value
      end

      def self.from_data(data)
        raw = data.is_a?(Hash) ? stringify_keys(data) : data
        value =
          if raw.is_a?(Hash)
            raw["value"] || raw["v"] || raw["data"] || raw["state"]
          else
            raw
          end

        new(raw: raw, value: value)
      end
    end

    class ChangeEvent < GenericEvent; end
    class FocusEvent < GenericEvent; end
    class BlurEvent < GenericEvent; end
    class ClickEvent < GenericEvent; end
    class SubmitEvent < GenericEvent; end
    class SelectEvent < GenericEvent; end
    class DismissEvent < GenericEvent; end
    class VisibleEvent < GenericEvent; end
    class ResultEvent < GenericEvent; end
    class UploadEvent < GenericEvent; end
    class ErrorEvent < GenericEvent; end
    class ActionEvent < GenericEvent; end
    class StateChangeEvent < GenericEvent
      attr_reader :state

      def initialize(raw:, value: nil, state: nil)
        super(raw: raw, value: value)
        @state = state
      end

      def self.from_data(data)
        raw = data.is_a?(Hash) ? stringify_keys(data) : {}
        state = raw["state"] || raw["value"] || raw["v"] || data
        new(raw: raw, value: state, state: state)
      end
    end

    class TapEvent < BasePayload
      attr_reader :kind, :local_position, :global_position

      def initialize(kind:, local_position:, global_position:)
        @kind = kind
        @local_position = local_position
        @global_position = global_position
      end

      def self.from_data(data)
        new(
          kind: pick(data, "k", "kind"),
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position")
        )
      end
    end

    class TapMoveEvent < BasePayload
      attr_reader :kind, :local_position, :global_position, :delta

      def initialize(kind:, local_position:, global_position:, delta:)
        @kind = kind
        @local_position = local_position
        @global_position = global_position
        @delta = delta
      end

      def self.from_data(data)
        new(
          kind: pick(data, "k", "kind"),
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          delta: offset(data, "d", "delta")
        )
      end
    end

    class MultiTapEvent < BasePayload
      attr_reader :correct_touches

      def initialize(correct_touches:)
        @correct_touches = correct_touches
      end

      def self.from_data(data)
        new(correct_touches: pick(data, "ct", "correct_touches"))
      end
    end

    class LongPressDownEvent < BasePayload
      attr_reader :kind, :local_position, :global_position

      def initialize(kind:, local_position:, global_position:)
        @kind = kind
        @local_position = local_position
        @global_position = global_position
      end

      def self.from_data(data)
        new(
          kind: pick(data, "k", "kind"),
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position")
        )
      end
    end

    class LongPressStartEvent < BasePayload
      attr_reader :local_position, :global_position

      def initialize(local_position:, global_position:)
        @local_position = local_position
        @global_position = global_position
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position")
        )
      end
    end

    class LongPressMoveUpdateEvent < BasePayload
      attr_reader :local_position, :global_position, :offset_from_origin, :local_offset_from_origin

      def initialize(local_position:, global_position:, offset_from_origin:, local_offset_from_origin:)
        @local_position = local_position
        @global_position = global_position
        @offset_from_origin = offset_from_origin
        @local_offset_from_origin = local_offset_from_origin
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          offset_from_origin: offset(data, "of", "offset_from_origin"),
          local_offset_from_origin: offset(data, "lofo", "local_offset_from_origin")
        )
      end
    end

    class LongPressEndEvent < BasePayload
      attr_reader :local_position, :global_position, :velocity

      def initialize(local_position:, global_position:, velocity:)
        @local_position = local_position
        @global_position = global_position
        @velocity = velocity
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          velocity: offset(data, "v", "velocity")
        )
      end
    end

    class DragDownEvent < BasePayload
      attr_reader :local_position, :global_position

      def initialize(local_position:, global_position:)
        @local_position = local_position
        @global_position = global_position
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position")
        )
      end
    end

    class DragStartEvent < BasePayload
      attr_reader :kind, :local_position, :global_position, :timestamp

      def initialize(kind:, local_position:, global_position:, timestamp:)
        @kind = kind
        @local_position = local_position
        @global_position = global_position
        @timestamp = timestamp
      end

      def self.from_data(data)
        new(
          kind: pick(data, "k", "kind"),
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          timestamp: duration(data, "ts", "timestamp")
        )
      end
    end

    class DragUpdateEvent < BasePayload
      attr_reader :local_position, :global_position, :local_delta, :global_delta, :primary_delta, :timestamp

      def initialize(local_position:, global_position:, local_delta:, global_delta:, primary_delta:, timestamp:)
        @local_position = local_position
        @global_position = global_position
        @local_delta = local_delta
        @global_delta = global_delta
        @primary_delta = primary_delta
        @timestamp = timestamp
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          local_delta: offset(data, "ld", "local_delta"),
          global_delta: offset(data, "gd", "global_delta"),
          primary_delta: pick(data, "pd", "primary_delta"),
          timestamp: duration(data, "ts", "timestamp")
        )
      end
    end

    class DragEndEvent < BasePayload
      attr_reader :local_position, :global_position, :velocity, :primary_velocity

      def initialize(local_position:, global_position:, velocity:, primary_velocity:)
        @local_position = local_position
        @global_position = global_position
        @velocity = velocity
        @primary_velocity = primary_velocity
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          velocity: offset(data, "v", "velocity"),
          primary_velocity: pick(data, "pv", "primary_velocity")
        )
      end
    end

    class ForcePressEvent < BasePayload
      attr_reader :local_position, :global_position, :pressure

      def initialize(local_position:, global_position:, pressure:)
        @local_position = local_position
        @global_position = global_position
        @pressure = pressure
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          pressure: pick(data, "p", "pressure")
        )
      end
    end

    class ScaleStartEvent < BasePayload
      attr_reader :local_focal_point, :global_focal_point, :pointer_count, :timestamp

      def initialize(local_focal_point:, global_focal_point:, pointer_count:, timestamp:)
        @local_focal_point = local_focal_point
        @global_focal_point = global_focal_point
        @pointer_count = pointer_count
        @timestamp = timestamp
      end

      def self.from_data(data)
        new(
          local_focal_point: offset(data, "lfp", "local_focal_point"),
          global_focal_point: offset(data, "gfp", "global_focal_point"),
          pointer_count: pick(data, "pc", "pointer_count"),
          timestamp: duration(data, "ts", "timestamp")
        )
      end
    end

    class ScaleUpdateEvent < BasePayload
      attr_reader :local_focal_point, :global_focal_point, :focal_point_delta,
                  :pointer_count, :horizontal_scale, :vertical_scale, :scale,
                  :rotation, :timestamp

      def initialize(local_focal_point:, global_focal_point:, focal_point_delta:, pointer_count:, horizontal_scale:, vertical_scale:, scale:, rotation:, timestamp:)
        @local_focal_point = local_focal_point
        @global_focal_point = global_focal_point
        @focal_point_delta = focal_point_delta
        @pointer_count = pointer_count
        @horizontal_scale = horizontal_scale
        @vertical_scale = vertical_scale
        @scale = scale
        @rotation = rotation
        @timestamp = timestamp
      end

      def self.from_data(data)
        new(
          local_focal_point: offset(data, "lfp", "local_focal_point"),
          global_focal_point: offset(data, "gfp", "global_focal_point"),
          focal_point_delta: offset(data, "fpd", "focal_point_delta"),
          pointer_count: pick(data, "pc", "pointer_count"),
          horizontal_scale: pick(data, "hs", "horizontal_scale"),
          vertical_scale: pick(data, "vs", "vertical_scale"),
          scale: pick(data, "s", "scale"),
          rotation: pick(data, "rot", "rotation"),
          timestamp: duration(data, "ts", "timestamp")
        )
      end
    end

    class ScaleEndEvent < BasePayload
      attr_reader :pointer_count, :velocity

      def initialize(pointer_count:, velocity:)
        @pointer_count = pointer_count
        @velocity = velocity
      end

      def self.from_data(data)
        new(
          pointer_count: pick(data, "pc", "pointer_count"),
          velocity: offset(data, "v", "velocity")
        )
      end
    end

    class PointerEvent < BasePayload
      attr_reader :kind, :local_position, :global_position, :timestamp,
                  :device, :pressure, :pressure_min, :pressure_max, :distance,
                  :distance_max, :size, :radius_major, :radius_minor,
                  :radius_min, :radius_max, :orientation, :tilt,
                  :local_delta, :global_delta

      def initialize(kind:, local_position:, global_position:, timestamp:, device:, pressure:, pressure_min:, pressure_max:, distance:, distance_max:, size:, radius_major:, radius_minor:, radius_min:, radius_max:, orientation:, tilt:, local_delta:, global_delta:)
        @kind = kind
        @local_position = local_position
        @global_position = global_position
        @timestamp = timestamp
        @device = device
        @pressure = pressure
        @pressure_min = pressure_min
        @pressure_max = pressure_max
        @distance = distance
        @distance_max = distance_max
        @size = size
        @radius_major = radius_major
        @radius_minor = radius_minor
        @radius_min = radius_min
        @radius_max = radius_max
        @orientation = orientation
        @tilt = tilt
        @local_delta = local_delta
        @global_delta = global_delta
      end

      def self.from_data(data)
        new(
          kind: pick(data, "k", "kind"),
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          timestamp: duration(data, "ts", "timestamp"),
          device: pick(data, "dev", "device"),
          pressure: pick(data, "ps", "pressure"),
          pressure_min: pick(data, "pMin", "pressure_min"),
          pressure_max: pick(data, "pMax", "pressure_max"),
          distance: pick(data, "dist", "distance"),
          distance_max: pick(data, "distMax", "distance_max"),
          size: pick(data, "size", "size"),
          radius_major: pick(data, "rMj", "radius_major"),
          radius_minor: pick(data, "rMn", "radius_minor"),
          radius_min: pick(data, "rMin", "radius_min"),
          radius_max: pick(data, "rMax", "radius_max"),
          orientation: pick(data, "or", "orientation"),
          tilt: pick(data, "tilt", "tilt"),
          local_delta: offset(data, "ld", "local_delta"),
          global_delta: offset(data, "gd", "global_delta")
        )
      end
    end

    HoverEvent = PointerEvent

    class ScrollEvent < BasePayload
      attr_reader :local_position, :global_position, :scroll_delta

      def initialize(local_position:, global_position:, scroll_delta:)
        @local_position = local_position
        @global_position = global_position
        @scroll_delta = scroll_delta
      end

      def self.from_data(data)
        new(
          local_position: offset(data, "l", "local_position"),
          global_position: offset(data, "g", "global_position"),
          scroll_delta: offset(data, "sd", "scroll_delta")
        )
      end
    end

    module GestureEventFactory
      module_function

      EVENT_CLASS_MAP = {
        "change" => ChangeEvent,
        "focus" => FocusEvent,
        "blur" => BlurEvent,
        "click" => ClickEvent,
        "submit" => SubmitEvent,
        "select" => SelectEvent,
        "dismiss" => DismissEvent,
        "visible" => VisibleEvent,
        "result" => ResultEvent,
        "upload" => UploadEvent,
        "error" => ErrorEvent,
        "action" => ActionEvent,
        "state_change" => StateChangeEvent,
        "confirm_pop" => GenericEvent,
        "route_change" => GenericEvent,
        "view_pop" => GenericEvent,
        "animation_end" => GenericEvent,
        "size_change" => GenericEvent,
        "selection_change" => GenericEvent,
        "entry_mode_change" => GenericEvent,
        "media_change" => GenericEvent,
        "resize" => GenericEvent,
        "load" => GenericEvent,
        "loaded" => GenericEvent,
        "accept" => GenericEvent,
        "will_accept" => GenericEvent,
        "accept_with_details" => GenericEvent,
        "move" => GenericEvent,
        "leave" => GenericEvent,
        "open" => GenericEvent,
        "close" => GenericEvent,
        "double_tap" => GenericEvent,
        "double_tap_down" => TapEvent,
        "tap_up" => TapEvent,
        "tap_cancel" => GenericEvent,
        "tap" => TapEvent,
        "tap_down" => TapEvent,
        "tap_move" => TapMoveEvent,
        "multi_tap" => MultiTapEvent,
        "multi_long_press" => GenericEvent,
        "long_press_down" => LongPressDownEvent,
        "long_press_cancel" => GenericEvent,
        "long_press" => GenericEvent,
        "long_press_start" => LongPressStartEvent,
        "long_press_move_update" => LongPressMoveUpdateEvent,
        "long_press_up" => GenericEvent,
        "long_press_end" => LongPressEndEvent,
        "secondary_tap" => TapEvent,
        "secondary_tap_down" => TapEvent,
        "secondary_tap_up" => TapEvent,
        "secondary_tap_cancel" => GenericEvent,
        "tertiary_tap_down" => TapEvent,
        "tertiary_tap_up" => TapEvent,
        "tertiary_tap_cancel" => GenericEvent,
        "secondary_long_press_down" => LongPressDownEvent,
        "secondary_long_press_cancel" => GenericEvent,
        "secondary_long_press" => GenericEvent,
        "secondary_long_press_start" => LongPressStartEvent,
        "secondary_long_press_move_update" => LongPressMoveUpdateEvent,
        "secondary_long_press_up" => GenericEvent,
        "secondary_long_press_end" => LongPressEndEvent,
        "tertiary_long_press_down" => LongPressDownEvent,
        "tertiary_long_press_cancel" => GenericEvent,
        "tertiary_long_press" => GenericEvent,
        "tertiary_long_press_start" => LongPressStartEvent,
        "tertiary_long_press_move_update" => LongPressMoveUpdateEvent,
        "tertiary_long_press_up" => GenericEvent,
        "tertiary_long_press_end" => LongPressEndEvent,
        "drag_down" => DragDownEvent,
        "horizontal_drag_down" => DragDownEvent,
        "horizontal_drag_cancel" => GenericEvent,
        "pan_start" => DragStartEvent,
        "pan_update" => DragUpdateEvent,
        "pan_end" => DragEndEvent,
        "pan_down" => DragDownEvent,
        "pan_cancel" => GenericEvent,
        "horizontal_drag_start" => DragStartEvent,
        "horizontal_drag_update" => DragUpdateEvent,
        "horizontal_drag_end" => DragEndEvent,
        "vertical_drag_down" => DragDownEvent,
        "vertical_drag_cancel" => GenericEvent,
        "vertical_drag_start" => DragStartEvent,
        "vertical_drag_update" => DragUpdateEvent,
        "vertical_drag_end" => DragEndEvent,
        "right_pan_start" => DragStartEvent,
        "right_pan_update" => DragUpdateEvent,
        "right_pan_end" => DragEndEvent,
        "force_press" => ForcePressEvent,
        "force_press_start" => ForcePressEvent,
        "force_press_peak" => ForcePressEvent,
        "force_press_update" => ForcePressEvent,
        "force_press_end" => ForcePressEvent,
        "scale_start" => ScaleStartEvent,
        "scale_update" => ScaleUpdateEvent,
        "scale_end" => ScaleEndEvent,
        "hover" => PointerEvent,
        "enter" => PointerEvent,
        "exit" => PointerEvent,
        "scroll" => ScrollEvent
      }.freeze

      def build(name, data)
        klass = EVENT_CLASS_MAP[name.to_s]
        return nil unless klass

        klass.from_data(data)
      end
    end
  end
end
