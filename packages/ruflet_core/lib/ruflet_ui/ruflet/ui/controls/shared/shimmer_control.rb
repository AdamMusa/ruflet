# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ShimmerControl < Ruflet::Control
          TYPE = "shimmer".freeze
          WIRE = "Shimmer".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, base_color: nil, bottom: nil, col: nil, content: nil, data: nil, direction: nil, disabled: nil, expand: nil, expand_loose: nil, gradient: nil, height: nil, highlight_color: nil, key: nil, left: nil, loop: nil, margin: nil, offset: nil, opacity: nil, period: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_size_change: nil)
            props = {}
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
            props[:base_color] = base_color unless base_color.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:direction] = direction unless direction.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:gradient] = gradient unless gradient.nil?
            props[:height] = height unless height.nil?
            props[:highlight_color] = highlight_color unless highlight_color.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:loop] = loop unless loop.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:period] = period unless period.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
