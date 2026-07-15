# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SafeAreaControl < Ruflet::Control
          TYPE = "safearea".freeze
          WIRE = "SafeArea".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :avoid_intrusions_bottom, :avoid_intrusions_left, :avoid_intrusions_right, :avoid_intrusions_top, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :maintain_bottom_view_padding, :margin, :minimum_padding, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            adaptive = props[:adaptive]
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
            avoid_intrusions_bottom = props[:avoid_intrusions_bottom]
            avoid_intrusions_left = props[:avoid_intrusions_left]
            avoid_intrusions_right = props[:avoid_intrusions_right]
            avoid_intrusions_top = props[:avoid_intrusions_top]
            badge = props[:badge]
            bottom = props[:bottom]
            col = props[:col]
            content = props[:content]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            maintain_bottom_view_padding = props[:maintain_bottom_view_padding]
            margin = props[:margin]
            minimum_padding = props[:minimum_padding]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_size_change = props[:on_size_change]
            raise ArgumentError, "safe_area requires content" if content.nil?

            avoid_intrusions_bottom = true if avoid_intrusions_bottom.nil?
            avoid_intrusions_left = true if avoid_intrusions_left.nil?
            avoid_intrusions_right = true if avoid_intrusions_right.nil?
            avoid_intrusions_top = true if avoid_intrusions_top.nil?
            maintain_bottom_view_padding = false if maintain_bottom_view_padding.nil?
            minimum_padding = 0 if minimum_padding.nil?

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
            props[:avoid_intrusions_bottom] = avoid_intrusions_bottom unless avoid_intrusions_bottom.nil?
            props[:avoid_intrusions_left] = avoid_intrusions_left unless avoid_intrusions_left.nil?
            props[:avoid_intrusions_right] = avoid_intrusions_right unless avoid_intrusions_right.nil?
            props[:avoid_intrusions_top] = avoid_intrusions_top unless avoid_intrusions_top.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:maintain_bottom_view_padding] = maintain_bottom_view_padding unless maintain_bottom_view_padding.nil?
            props[:margin] = margin unless margin.nil?
            props[:minimum_padding] = minimum_padding unless minimum_padding.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
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
