# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RangeSliderControl < Ruflet::Control
          TYPE = "rangeslider".freeze
          WIRE = "RangeSlider".freeze

          def initialize(id: nil, active_color: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, col: nil, data: nil, disabled: nil, divisions: nil, end_value: nil, expand: nil, expand_loose: nil, height: nil, inactive_color: nil, key: nil, label: nil, left: nil, margin: nil, max: nil, min: nil, mouse_cursor: nil, offset: nil, opacity: nil, overlay_color: nil, right: nil, rotate: nil, round: nil, rtl: nil, scale: nil, size_change_interval: nil, start_value: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_change: nil, on_change_end: nil, on_change_start: nil, on_size_change: nil)
            props = {}
            props[:active_color] = active_color unless active_color.nil?
            props[:align] = align unless align.nil?
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
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divisions] = divisions unless divisions.nil?
            props[:end_value] = end_value unless end_value.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:inactive_color] = inactive_color unless inactive_color.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:max] = max unless max.nil?
            props[:min] = min unless min.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:overlay_color] = overlay_color unless overlay_color.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:round] = round unless round.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:start_value] = start_value unless start_value.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_change_end] = on_change_end unless on_change_end.nil?
            props[:on_change_start] = on_change_start unless on_change_start.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
