# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class GestureDetectorControl < Ruflet::Control
          TYPE = "gesturedetector".freeze
          WIRE = "GestureDetector".freeze

          KEYWORDS = [:adaptive, :align, :allowed_devices, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :drag_interval, :exclude_from_semantics, :expand, :expand_loose, :height, :hover_interval, :key, :left, :margin, :mouse_cursor, :multi_tap_touches, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :trackpad_scroll_causes_scale, :visible, :width, :on_animation_end, :on_double_tap, :on_double_tap_cancel, :on_double_tap_down, :on_enter, :on_exit, :on_force_press_end, :on_force_press_peak, :on_force_press_start, :on_force_press_update, :on_horizontal_drag_cancel, :on_horizontal_drag_down, :on_horizontal_drag_end, :on_horizontal_drag_start, :on_horizontal_drag_update, :on_hover, :on_long_press, :on_long_press_cancel, :on_long_press_down, :on_long_press_end, :on_long_press_move_update, :on_long_press_start, :on_long_press_up, :on_multi_long_press, :on_multi_tap, :on_pan_cancel, :on_pan_down, :on_pan_end, :on_pan_start, :on_pan_update, :on_right_pan_end, :on_right_pan_start, :on_right_pan_update, :on_scale_end, :on_scale_start, :on_scale_update, :on_scroll, :on_secondary_long_press, :on_secondary_long_press_cancel, :on_secondary_long_press_down, :on_secondary_long_press_end, :on_secondary_long_press_move_update, :on_secondary_long_press_start, :on_secondary_long_press_up, :on_secondary_tap, :on_secondary_tap_cancel, :on_secondary_tap_down, :on_secondary_tap_up, :on_size_change, :on_tap, :on_tap_cancel, :on_tap_down, :on_tap_move, :on_tap_up, :on_tertiary_long_press, :on_tertiary_long_press_cancel, :on_tertiary_long_press_down, :on_tertiary_long_press_end, :on_tertiary_long_press_move_update, :on_tertiary_long_press_start, :on_tertiary_long_press_up, :on_tertiary_tap_cancel, :on_tertiary_tap_down, :on_tertiary_tap_up, :on_vertical_drag_cancel, :on_vertical_drag_down, :on_vertical_drag_end, :on_vertical_drag_start, :on_vertical_drag_update].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
