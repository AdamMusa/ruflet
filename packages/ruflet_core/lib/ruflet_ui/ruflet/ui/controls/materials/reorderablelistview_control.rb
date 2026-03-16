# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ReorderableListViewControl < Ruflet::Control
          TYPE = "reorderablelistview".freeze
          WIRE = "ReorderableListView".freeze

          def initialize(id: nil, adaptive: nil, align: nil, anchor: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, auto_scroll: nil, auto_scroller_velocity_scalar: nil, badge: nil, bottom: nil, build_controls_on_demand: nil, cache_extent: nil, clip_behavior: nil, col: nil, controls: nil, data: nil, disabled: nil, divider_thickness: nil, expand: nil, expand_loose: nil, first_item_prototype: nil, footer: nil, header: nil, height: nil, horizontal: nil, item_extent: nil, key: nil, left: nil, margin: nil, mouse_cursor: nil, offset: nil, opacity: nil, padding: nil, prototype_item: nil, reverse: nil, right: nil, rotate: nil, rtl: nil, scale: nil, scroll: nil, scroll_interval: nil, semantic_child_count: nil, show_default_drag_handles: nil, size_change_interval: nil, spacing: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_reorder: nil, on_reorder_end: nil, on_reorder_start: nil, on_scroll: nil, on_size_change: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:align] = align unless align.nil?
            props[:anchor] = anchor unless anchor.nil?
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
            props[:auto_scroller_velocity_scalar] = auto_scroller_velocity_scalar unless auto_scroller_velocity_scalar.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:build_controls_on_demand] = build_controls_on_demand unless build_controls_on_demand.nil?
            props[:cache_extent] = cache_extent unless cache_extent.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_thickness] = divider_thickness unless divider_thickness.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:first_item_prototype] = first_item_prototype unless first_item_prototype.nil?
            props[:footer] = footer unless footer.nil?
            props[:header] = header unless header.nil?
            props[:height] = height unless height.nil?
            props[:horizontal] = horizontal unless horizontal.nil?
            props[:item_extent] = item_extent unless item_extent.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:prototype_item] = prototype_item unless prototype_item.nil?
            props[:reverse] = reverse unless reverse.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:scroll] = scroll unless scroll.nil?
            props[:scroll_interval] = scroll_interval unless scroll_interval.nil?
            props[:semantic_child_count] = semantic_child_count unless semantic_child_count.nil?
            props[:show_default_drag_handles] = show_default_drag_handles unless show_default_drag_handles.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_reorder] = on_reorder unless on_reorder.nil?
            props[:on_reorder_end] = on_reorder_end unless on_reorder_end.nil?
            props[:on_reorder_start] = on_reorder_start unless on_reorder_start.nil?
            props[:on_scroll] = on_scroll unless on_scroll.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
