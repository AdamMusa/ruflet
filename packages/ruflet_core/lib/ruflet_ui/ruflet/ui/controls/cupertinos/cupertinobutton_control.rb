# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoButtonControl < Ruflet::Control
          TYPE = "cupertinobutton".freeze
          WIRE = "CupertinoButton".freeze

          KEYWORDS = [:align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :border_radius, :bottom, :col, :color, :content, :data, :disabled, :disabled_bgcolor, :expand, :expand_loose, :focus_color, :height, :icon, :icon_color, :key, :left, :margin, :min_size, :mouse_cursor, :offset, :opacity, :opacity_on_click, :padding, :right, :rotate, :rtl, :scale, :size, :size_change_interval, :tooltip, :top, :url, :visible, :width, :on_animation_end, :on_blur, :on_click, :on_focus, :on_long_press, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            align = props[:align]
            alignment = props[:alignment]
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
            bgcolor = props[:bgcolor]
            border_radius = props[:border_radius]
            bottom = props[:bottom]
            col = props[:col]
            color = props[:color]
            content = props[:content]
            data = props[:data]
            disabled = props[:disabled]
            disabled_bgcolor = props[:disabled_bgcolor]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            focus_color = props[:focus_color]
            height = props[:height]
            icon = props[:icon]
            icon_color = props[:icon_color]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            min_size = props[:min_size]
            mouse_cursor = props[:mouse_cursor]
            offset = props[:offset]
            opacity = props[:opacity]
            opacity_on_click = props[:opacity_on_click]
            padding = props[:padding]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size = props[:size]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            url = props[:url]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_click = props[:on_click]
            on_focus = props[:on_focus]
            on_long_press = props[:on_long_press]
            on_size_change = props[:on_size_change]
            alignment = "center" if alignment.nil?
            autofocus = false if autofocus.nil?
            border_radius = { "all" => 8.0 } if border_radius.nil?
            opacity_on_click = 0.4 if opacity_on_click.nil?
            size = "large" if size.nil?

            props = {}
            props[:align] = align unless align.nil?
            props[:alignment] = alignment unless alignment.nil?
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
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_bgcolor] = disabled_bgcolor unless disabled_bgcolor.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:min_size] = min_size unless min_size.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:opacity_on_click] = opacity_on_click unless opacity_on_click.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size] = size unless size.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
