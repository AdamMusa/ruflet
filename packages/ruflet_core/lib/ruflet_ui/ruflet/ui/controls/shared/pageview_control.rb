# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PageViewControl < Ruflet::Control
          TYPE = "pageview".freeze
          WIRE = "PageView".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :clip_behavior, :col, :controls, :data, :disabled, :expand, :expand_loose, :height, :horizontal, :implicit_scrolling, :keep_page, :key, :left, :margin, :offset, :opacity, :pad_ends, :reverse, :right, :rotate, :rtl, :scale, :selected_index, :size_change_interval, :snap, :tooltip, :top, :viewport_fraction, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            align = props[:align]
            animate_align = props[:animate_align]
            animate_margin = props[:animate_margin]
            animate_offset = props[:animate_offset]
            animate_opacity = props[:animate_opacity]
            animate_position = props[:animate_position]
            animate_rotation = props[:animate_rotation]
            animate_scale = props[:animate_scale]
            animate_size = props[:animate_size]
            aspect_ratio = props[:aspect_ratio]
            badge = props[:badge]
            bottom = props[:bottom]
            clip_behavior = props[:clip_behavior]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            horizontal = props[:horizontal]
            implicit_scrolling = props[:implicit_scrolling]
            keep_page = props[:keep_page]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            pad_ends = props[:pad_ends]
            reverse = props[:reverse]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            selected_index = props[:selected_index]
            size_change_interval = props[:size_change_interval]
            snap = props[:snap]
            tooltip = props[:tooltip]
            top = props[:top]
            viewport_fraction = props[:viewport_fraction]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_change = props[:on_change]
            on_size_change = props[:on_size_change]
            clip_behavior = "hardEdge" if clip_behavior.nil?
            horizontal = true if horizontal.nil?
            implicit_scrolling = false if implicit_scrolling.nil?
            keep_page = true if keep_page.nil?
            pad_ends = true if pad_ends.nil?
            reverse = false if reverse.nil?
            selected_index = 0 if selected_index.nil?
            snap = true if snap.nil?
            viewport_fraction = 1.0 if viewport_fraction.nil?

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
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:horizontal] = horizontal unless horizontal.nil?
            props[:implicit_scrolling] = implicit_scrolling unless implicit_scrolling.nil?
            props[:keep_page] = keep_page unless keep_page.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:pad_ends] = pad_ends unless pad_ends.nil?
            props[:reverse] = reverse unless reverse.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected_index] = selected_index unless selected_index.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:snap] = snap unless snap.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:viewport_fraction] = viewport_fraction unless viewport_fraction.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
