# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoSlidingSegmentedButtonControl < Ruflet::Control
          TYPE = "cupertinoslidingsegmentedbutton".freeze
          WIRE = "CupertinoSlidingSegmentedButton".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :controls, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :padding, :proportional_width, :right, :rotate, :rtl, :scale, :selected_index, :size_change_interval, :thumb_color, :tooltip, :top, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
            bgcolor = props[:bgcolor]
            bottom = props[:bottom]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            padding = props[:padding]
            proportional_width = props[:proportional_width]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            selected_index = props[:selected_index]
            size_change_interval = props[:size_change_interval]
            thumb_color = props[:thumb_color]
            tooltip = props[:tooltip]
            top = props[:top]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_change = props[:on_change]
            on_size_change = props[:on_size_change]
            proportional_width = false if proportional_width.nil?
            selected_index = 0 if selected_index.nil?

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
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:proportional_width] = proportional_width unless proportional_width.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected_index] = selected_index unless selected_index.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:thumb_color] = thumb_color unless thumb_color.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
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
