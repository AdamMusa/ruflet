# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ListSectionControl < Ruflet::Control
          TYPE = "listsection".freeze
          WIRE = "ListSection".freeze

          KEYWORDS = [:additional_divider_margin, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :border_radius, :bottom, :clip_behavior, :col, :controls, :data, :disabled, :divider_margin, :expand, :expand_loose, :footer, :has_leading, :header, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rows_bgcolor, :rtl, :scale, :separator_color, :size_change_interval, :tooltip, :top, :top_margin, :variant, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            additional_divider_margin = props[:additional_divider_margin]
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
            bgcolor = props[:bgcolor]
            border_radius = props[:border_radius]
            bottom = props[:bottom]
            clip_behavior = props[:clip_behavior]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            divider_margin = props[:divider_margin]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            footer = props[:footer]
            has_leading = props[:has_leading]
            header = props[:header]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rows_bgcolor = props[:rows_bgcolor]
            rtl = props[:rtl]
            scale = props[:scale]
            separator_color = props[:separator_color]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            top_margin = props[:top_margin]
            variant = props[:variant]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_size_change = props[:on_size_change]
            variant = "insetGrouped" if variant.nil?

            props = {}
            props[:additional_divider_margin] = additional_divider_margin unless additional_divider_margin.nil?
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
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_margin] = divider_margin unless divider_margin.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:footer] = footer unless footer.nil?
            props[:has_leading] = has_leading unless has_leading.nil?
            props[:header] = header unless header.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rows_bgcolor] = rows_bgcolor unless rows_bgcolor.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:separator_color] = separator_color unless separator_color.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:top_margin] = top_margin unless top_margin.nil?
            props[:variant] = variant unless variant.nil?
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
