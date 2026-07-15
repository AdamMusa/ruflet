# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoCheckboxControl < Ruflet::Control
          TYPE = "cupertinocheckbox".freeze
          WIRE = "CupertinoCheckbox".freeze

          KEYWORDS = [:active_color, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :border_side, :bottom, :check_color, :col, :data, :disabled, :expand, :expand_loose, :fill_color, :focus_color, :height, :key, :label, :label_position, :left, :margin, :mouse_cursor, :offset, :opacity, :right, :rotate, :rtl, :scale, :semantics_label, :shape, :size_change_interval, :spacing, :tooltip, :top, :tristate, :value, :visible, :width, :on_animation_end, :on_blur, :on_change, :on_focus, :on_size_change].freeze

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
            border_side = props[:border_side]
            bottom = props[:bottom]
            check_color = props[:check_color]
            col = props[:col]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            fill_color = props[:fill_color]
            focus_color = props[:focus_color]
            height = props[:height]
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
            semantics_label = props[:semantics_label]
            shape = props[:shape]
            size_change_interval = props[:size_change_interval]
            spacing = props[:spacing]
            tooltip = props[:tooltip]
            top = props[:top]
            tristate = props[:tristate]
            value = props[:value]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_change = props[:on_change]
            on_focus = props[:on_focus]
            on_size_change = props[:on_size_change]
            autofocus = false if autofocus.nil?
            label_position = "right" if label_position.nil?
            spacing = 10 if spacing.nil?
            tristate = false if tristate.nil?
            value = false if value.nil?

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
            props[:border_side] = border_side unless border_side.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:check_color] = check_color unless check_color.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
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
            props[:semantics_label] = semantics_label unless semantics_label.nil?
            props[:shape] = shape unless shape.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:tristate] = tristate unless tristate.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
