# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PlaceholderControl < Ruflet::Control
          TYPE = "placeholder".freeze
          WIRE = "Placeholder".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :color, :content, :data, :disabled, :expand, :expand_loose, :fallback_height, :fallback_width, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :stroke_width, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

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
            col = props[:col]
            color = props[:color]
            content = props[:content]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            fallback_height = props[:fallback_height]
            fallback_width = props[:fallback_width]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            stroke_width = props[:stroke_width]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_size_change = props[:on_size_change]
            fallback_height = 400.0 if fallback_height.nil?
            fallback_width = 400.0 if fallback_width.nil?
            stroke_width = 2.0 if stroke_width.nil?

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
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fallback_height] = fallback_height unless fallback_height.nil?
            props[:fallback_width] = fallback_width unless fallback_width.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:stroke_width] = stroke_width unless stroke_width.nil?
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
