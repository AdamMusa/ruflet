# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CustomScrollViewControl < Ruflet::Control
          TYPE = "customscrollview".freeze
          WIRE = "CustomScrollView".freeze

          KEYWORDS = [:align, :anchor, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :badge, :bottom, :cache_extent, :clip_behavior, :col, :controls, :data, :disabled, :expand, :expand_loose, :height, :horizontal, :key, :keyboard_dismiss_behavior, :left, :margin, :offset, :opacity, :reverse, :right, :rotate, :rtl, :scale, :scroll, :scroll_interval, :semantic_child_count, :size_change_interval, :slivers, :tooltip, :top, :visible, :width, :on_animation_end, :on_scroll, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            align = props[:align]
            anchor = props[:anchor]
            animate_align = props[:animate_align]
            animate_margin = props[:animate_margin]
            animate_offset = props[:animate_offset]
            animate_opacity = props[:animate_opacity]
            animate_position = props[:animate_position]
            animate_rotation = props[:animate_rotation]
            animate_scale = props[:animate_scale]
            animate_size = props[:animate_size]
            aspect_ratio = props[:aspect_ratio]
            auto_scroll = props[:auto_scroll]
            badge = props[:badge]
            bottom = props[:bottom]
            cache_extent = props[:cache_extent]
            clip_behavior = props[:clip_behavior]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            horizontal = props[:horizontal]
            key = props[:key]
            keyboard_dismiss_behavior = props[:keyboard_dismiss_behavior]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            reverse = props[:reverse]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            scroll = props[:scroll]
            scroll_interval = props[:scroll_interval]
            semantic_child_count = props[:semantic_child_count]
            size_change_interval = props[:size_change_interval]
            slivers = props[:slivers]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_scroll = props[:on_scroll]
            on_size_change = props[:on_size_change]
            horizontal = false if horizontal.nil?
            reverse = false if reverse.nil?

            props = {}
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
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:cache_extent] = cache_extent unless cache_extent.nil?
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
            props[:keyboard_dismiss_behavior] = keyboard_dismiss_behavior unless keyboard_dismiss_behavior.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:reverse] = reverse unless reverse.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:scroll] = scroll unless scroll.nil?
            props[:scroll_interval] = scroll_interval unless scroll_interval.nil?
            props[:semantic_child_count] = semantic_child_count unless semantic_child_count.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:slivers] = slivers unless slivers.nil?
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
