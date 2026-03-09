# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class GestureDetectorControl < Ruflet::Control
          TYPE = "gesturedetector".freeze
          WIRE = "GestureDetector".freeze

          def initialize(id: nil, adaptive: nil, align: nil, allowed_devices: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, col: nil, content: nil, data: nil, disabled: nil, drag_interval: nil, exclude_from_semantics: nil, expand: nil, expand_loose: nil, height: nil, hover_interval: nil, key: nil, left: nil, margin: nil, mouse_cursor: nil, multi_tap_touches: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, tooltip: nil, top: nil, trackpad_scroll_causes_scale: nil, visible: nil, width: nil, on_animation_end: nil, on_double_tap: nil, on_double_tap_cancel: nil, on_double_tap_down: nil, on_enter: nil, on_exit: nil, on_force_press_end: nil, on_force_press_peak: nil, on_force_press_start: nil, on_force_press_update: nil, on_horizontal_drag_cancel: nil, on_horizontal_drag_down: nil, on_horizontal_drag_end: nil, on_horizontal_drag_start: nil, on_horizontal_drag_update: nil, on_hover: nil, on_long_press: nil, on_long_press_cancel: nil, on_long_press_down: nil, on_long_press_end: nil, on_long_press_move_update: nil, on_long_press_start: nil, on_long_press_up: nil, on_multi_long_press: nil, on_multi_tap: nil, on_pan_cancel: nil, on_pan_down: nil, on_pan_end: nil, on_pan_start: nil, on_pan_update: nil, on_right_pan_end: nil, on_right_pan_start: nil, on_right_pan_update: nil, on_scale_end: nil, on_scale_start: nil, on_scale_update: nil, on_scroll: nil, on_secondary_long_press: nil, on_secondary_long_press_cancel: nil, on_secondary_long_press_down: nil, on_secondary_long_press_end: nil, on_secondary_long_press_move_update: nil, on_secondary_long_press_start: nil, on_secondary_long_press_up: nil, on_secondary_tap: nil, on_secondary_tap_cancel: nil, on_secondary_tap_down: nil, on_secondary_tap_up: nil, on_size_change: nil, on_tap: nil, on_tap_cancel: nil, on_tap_down: nil, on_tap_move: nil, on_tap_up: nil, on_tertiary_long_press: nil, on_tertiary_long_press_cancel: nil, on_tertiary_long_press_down: nil, on_tertiary_long_press_end: nil, on_tertiary_long_press_move_update: nil, on_tertiary_long_press_start: nil, on_tertiary_long_press_up: nil, on_tertiary_tap_cancel: nil, on_tertiary_tap_down: nil, on_tertiary_tap_up: nil, on_vertical_drag_cancel: nil, on_vertical_drag_down: nil, on_vertical_drag_end: nil, on_vertical_drag_start: nil, on_vertical_drag_update: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:allowed_devices] = allowed_devices unless allowed_devices.nil?
            props[:animate_align] = animate_align unless animate_align.nil?
            props[:animate_margin] = animate_margin unless animate_margin.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animate_size] = animate_size unless animate_size.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:drag_interval] = drag_interval unless drag_interval.nil?
            props[:exclude_from_semantics] = exclude_from_semantics unless exclude_from_semantics.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:hover_interval] = hover_interval unless hover_interval.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:multi_tap_touches] = multi_tap_touches unless multi_tap_touches.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trackpad_scroll_causes_scale] = trackpad_scroll_causes_scale unless trackpad_scroll_causes_scale.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_double_tap] = on_double_tap unless on_double_tap.nil?
            props[:on_double_tap_cancel] = on_double_tap_cancel unless on_double_tap_cancel.nil?
            props[:on_double_tap_down] = on_double_tap_down unless on_double_tap_down.nil?
            props[:on_enter] = on_enter unless on_enter.nil?
            props[:on_exit] = on_exit unless on_exit.nil?
            props[:on_force_press_end] = on_force_press_end unless on_force_press_end.nil?
            props[:on_force_press_peak] = on_force_press_peak unless on_force_press_peak.nil?
            props[:on_force_press_start] = on_force_press_start unless on_force_press_start.nil?
            props[:on_force_press_update] = on_force_press_update unless on_force_press_update.nil?
            props[:on_horizontal_drag_cancel] = on_horizontal_drag_cancel unless on_horizontal_drag_cancel.nil?
            props[:on_horizontal_drag_down] = on_horizontal_drag_down unless on_horizontal_drag_down.nil?
            props[:on_horizontal_drag_end] = on_horizontal_drag_end unless on_horizontal_drag_end.nil?
            props[:on_horizontal_drag_start] = on_horizontal_drag_start unless on_horizontal_drag_start.nil?
            props[:on_horizontal_drag_update] = on_horizontal_drag_update unless on_horizontal_drag_update.nil?
            props[:on_hover] = on_hover unless on_hover.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_long_press_cancel] = on_long_press_cancel unless on_long_press_cancel.nil?
            props[:on_long_press_down] = on_long_press_down unless on_long_press_down.nil?
            props[:on_long_press_end] = on_long_press_end unless on_long_press_end.nil?
            props[:on_long_press_move_update] = on_long_press_move_update unless on_long_press_move_update.nil?
            props[:on_long_press_start] = on_long_press_start unless on_long_press_start.nil?
            props[:on_long_press_up] = on_long_press_up unless on_long_press_up.nil?
            props[:on_multi_long_press] = on_multi_long_press unless on_multi_long_press.nil?
            props[:on_multi_tap] = on_multi_tap unless on_multi_tap.nil?
            props[:on_pan_cancel] = on_pan_cancel unless on_pan_cancel.nil?
            props[:on_pan_down] = on_pan_down unless on_pan_down.nil?
            props[:on_pan_end] = on_pan_end unless on_pan_end.nil?
            props[:on_pan_start] = on_pan_start unless on_pan_start.nil?
            props[:on_pan_update] = on_pan_update unless on_pan_update.nil?
            props[:on_right_pan_end] = on_right_pan_end unless on_right_pan_end.nil?
            props[:on_right_pan_start] = on_right_pan_start unless on_right_pan_start.nil?
            props[:on_right_pan_update] = on_right_pan_update unless on_right_pan_update.nil?
            props[:on_scale_end] = on_scale_end unless on_scale_end.nil?
            props[:on_scale_start] = on_scale_start unless on_scale_start.nil?
            props[:on_scale_update] = on_scale_update unless on_scale_update.nil?
            props[:on_scroll] = on_scroll unless on_scroll.nil?
            props[:on_secondary_long_press] = on_secondary_long_press unless on_secondary_long_press.nil?
            props[:on_secondary_long_press_cancel] = on_secondary_long_press_cancel unless on_secondary_long_press_cancel.nil?
            props[:on_secondary_long_press_down] = on_secondary_long_press_down unless on_secondary_long_press_down.nil?
            props[:on_secondary_long_press_end] = on_secondary_long_press_end unless on_secondary_long_press_end.nil?
            props[:on_secondary_long_press_move_update] = on_secondary_long_press_move_update unless on_secondary_long_press_move_update.nil?
            props[:on_secondary_long_press_start] = on_secondary_long_press_start unless on_secondary_long_press_start.nil?
            props[:on_secondary_long_press_up] = on_secondary_long_press_up unless on_secondary_long_press_up.nil?
            props[:on_secondary_tap] = on_secondary_tap unless on_secondary_tap.nil?
            props[:on_secondary_tap_cancel] = on_secondary_tap_cancel unless on_secondary_tap_cancel.nil?
            props[:on_secondary_tap_down] = on_secondary_tap_down unless on_secondary_tap_down.nil?
            props[:on_secondary_tap_up] = on_secondary_tap_up unless on_secondary_tap_up.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            props[:on_tap_cancel] = on_tap_cancel unless on_tap_cancel.nil?
            props[:on_tap_down] = on_tap_down unless on_tap_down.nil?
            props[:on_tap_move] = on_tap_move unless on_tap_move.nil?
            props[:on_tap_up] = on_tap_up unless on_tap_up.nil?
            props[:on_tertiary_long_press] = on_tertiary_long_press unless on_tertiary_long_press.nil?
            props[:on_tertiary_long_press_cancel] = on_tertiary_long_press_cancel unless on_tertiary_long_press_cancel.nil?
            props[:on_tertiary_long_press_down] = on_tertiary_long_press_down unless on_tertiary_long_press_down.nil?
            props[:on_tertiary_long_press_end] = on_tertiary_long_press_end unless on_tertiary_long_press_end.nil?
            props[:on_tertiary_long_press_move_update] = on_tertiary_long_press_move_update unless on_tertiary_long_press_move_update.nil?
            props[:on_tertiary_long_press_start] = on_tertiary_long_press_start unless on_tertiary_long_press_start.nil?
            props[:on_tertiary_long_press_up] = on_tertiary_long_press_up unless on_tertiary_long_press_up.nil?
            props[:on_tertiary_tap_cancel] = on_tertiary_tap_cancel unless on_tertiary_tap_cancel.nil?
            props[:on_tertiary_tap_down] = on_tertiary_tap_down unless on_tertiary_tap_down.nil?
            props[:on_tertiary_tap_up] = on_tertiary_tap_up unless on_tertiary_tap_up.nil?
            props[:on_vertical_drag_cancel] = on_vertical_drag_cancel unless on_vertical_drag_cancel.nil?
            props[:on_vertical_drag_down] = on_vertical_drag_down unless on_vertical_drag_down.nil?
            props[:on_vertical_drag_end] = on_vertical_drag_end unless on_vertical_drag_end.nil?
            props[:on_vertical_drag_start] = on_vertical_drag_start unless on_vertical_drag_start.nil?
            props[:on_vertical_drag_update] = on_vertical_drag_update unless on_vertical_drag_update.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
