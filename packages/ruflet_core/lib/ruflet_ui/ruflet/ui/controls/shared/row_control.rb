# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RowControl < Ruflet::Control
          TYPE = "row".freeze
          WIRE = "Row".freeze

          def initialize(id: nil, adaptive: nil, align: nil, alignment: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, auto_scroll: nil, badge: nil, bottom: nil, col: nil, controls: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, intrinsic_height: nil, key: nil, left: nil, margin: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, run_alignment: nil, run_spacing: nil, scale: nil, scroll: nil, scroll_interval: nil, size_change_interval: nil, spacing: nil, tight: nil, tooltip: nil, top: nil, vertical_alignment: nil, visible: nil, width: nil, wrap: nil, on_animation_end: nil, on_scroll: nil, on_size_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:alignment] = alignment unless alignment.nil?
            props[:animate_align] = animate_align unless animate_align.nil?
            props[:animate_margin] = animate_margin unless animate_margin.nil?
            props[:animate_offset] = animate_offset unless animate_offset.nil?
            props[:animate_opacity] = animate_opacity unless animate_opacity.nil?
            props[:animate_position] = animate_position unless animate_position.nil?
            props[:animate_rotation] = animate_rotation unless animate_rotation.nil?
            props[:animate_scale] = animate_scale unless animate_scale.nil?
            props[:animate_size] = animate_size unless animate_size.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:auto_scroll] = auto_scroll unless auto_scroll.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:intrinsic_height] = intrinsic_height unless intrinsic_height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:run_alignment] = run_alignment unless run_alignment.nil?
            props[:run_spacing] = run_spacing unless run_spacing.nil?
            props[:scale] = scale unless scale.nil?
            props[:scroll] = scroll unless scroll.nil?
            props[:scroll_interval] = scroll_interval unless scroll_interval.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tight] = tight unless tight.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:vertical_alignment] = vertical_alignment unless vertical_alignment.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:wrap] = wrap unless wrap.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_scroll] = on_scroll unless on_scroll.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
