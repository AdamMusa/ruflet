# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class GridViewControl < Ruflet::Control
          TYPE = "gridview".freeze
          WIRE = "GridView".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, auto_scroll: nil, badge: nil, bottom: nil, build_controls_on_demand: nil, cache_extent: nil, child_aspect_ratio: nil, clip_behavior: nil, col: nil, controls: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, horizontal: nil, key: nil, left: nil, margin: nil, max_extent: nil, offset: nil, opacity: nil, padding: nil, reverse: nil, right: nil, rotate: nil, rtl: nil, run_spacing: nil, runs_count: nil, scale: nil, scroll: nil, scroll_interval: nil, semantic_child_count: nil, size_change_interval: nil, spacing: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_scroll: nil, on_size_change: nil)
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
            props[:auto_scroll] = auto_scroll unless auto_scroll.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:build_controls_on_demand] = build_controls_on_demand unless build_controls_on_demand.nil?
            props[:cache_extent] = cache_extent unless cache_extent.nil?
            props[:child_aspect_ratio] = child_aspect_ratio unless child_aspect_ratio.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:horizontal] = horizontal unless horizontal.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:max_extent] = max_extent unless max_extent.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:reverse] = reverse unless reverse.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:run_spacing] = run_spacing unless run_spacing.nil?
            props[:runs_count] = runs_count unless runs_count.nil?
            props[:scale] = scale unless scale.nil?
            props[:scroll] = scroll unless scroll.nil?
            props[:scroll_interval] = scroll_interval unless scroll_interval.nil?
            props[:semantic_child_count] = semantic_child_count unless semantic_child_count.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
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
