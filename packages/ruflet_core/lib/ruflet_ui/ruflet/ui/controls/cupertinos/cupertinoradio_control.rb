# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoRadioControl < Ruflet::Control
          TYPE = "cupertinoradio".freeze
          WIRE = "CupertinoRadio".freeze

          KEYWORDS = [:active_color, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bottom, :col, :data, :disabled, :expand, :expand_loose, :fill_color, :focus_color, :height, :inactive_color, :key, :label, :label_position, :left, :margin, :mouse_cursor, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :toggleable, :tooltip, :top, :use_checkmark_style, :value, :visible, :width, :on_animation_end, :on_blur, :on_focus, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            active_color = props[:active_color]
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
            autofocus = props[:autofocus]
            badge = props[:badge]
            bottom = props[:bottom]
            col = props[:col]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            fill_color = props[:fill_color]
            focus_color = props[:focus_color]
            height = props[:height]
            inactive_color = props[:inactive_color]
            key = props[:key]
            label = props[:label]
            label_position = props[:label_position]
            left = props[:left]
            margin = props[:margin]
            mouse_cursor = props[:mouse_cursor]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            toggleable = props[:toggleable]
            tooltip = props[:tooltip]
            top = props[:top]
            use_checkmark_style = props[:use_checkmark_style]
            value = props[:value]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_focus = props[:on_focus]
            on_size_change = props[:on_size_change]
            autofocus = false if autofocus.nil?
            label_position = "right" if label_position.nil?
            toggleable = false if toggleable.nil?
            use_checkmark_style = false if use_checkmark_style.nil?
            value = "" if value.nil?

            props = {}
            props[:active_color] = active_color unless active_color.nil?
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
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
            props[:inactive_color] = inactive_color unless inactive_color.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_position] = label_position unless label_position.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:toggleable] = toggleable unless toggleable.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:use_checkmark_style] = use_checkmark_style unless use_checkmark_style.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
