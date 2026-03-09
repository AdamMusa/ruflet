# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DismissibleControl < Ruflet::Control
          TYPE = "dismissible".freeze
          WIRE = "Dismissible".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, background: nil, badge: nil, bottom: nil, col: nil, content: nil, cross_axis_end_offset: nil, data: nil, disabled: nil, dismiss_direction: nil, dismiss_thresholds: nil, expand: nil, expand_loose: nil, height: nil, key: nil, left: nil, margin: nil, movement_duration: nil, offset: nil, opacity: nil, resize_duration: nil, right: nil, rotate: nil, rtl: nil, scale: nil, secondary_background: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_confirm_dismiss: nil, on_dismiss: nil, on_resize: nil, on_size_change: nil, on_update: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
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
            props[:background] = background unless background.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:cross_axis_end_offset] = cross_axis_end_offset unless cross_axis_end_offset.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:dismiss_direction] = dismiss_direction unless dismiss_direction.nil?
            props[:dismiss_thresholds] = dismiss_thresholds unless dismiss_thresholds.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:movement_duration] = movement_duration unless movement_duration.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:resize_duration] = resize_duration unless resize_duration.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:secondary_background] = secondary_background unless secondary_background.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_confirm_dismiss] = on_confirm_dismiss unless on_confirm_dismiss.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_resize] = on_resize unless on_resize.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_update] = on_update unless on_update.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
