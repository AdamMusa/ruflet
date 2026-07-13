# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class FilledIconButtonControl < Ruflet::Control
          TYPE = "fillediconbutton".freeze
          WIRE = "FilledIconButton".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :bottom, :col, :data, :disabled, :disabled_color, :enable_feedback, :expand, :expand_loose, :focus_color, :height, :highlight_color, :hover_color, :icon, :icon_color, :icon_size, :key, :left, :margin, :mouse_cursor, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :selected, :selected_icon, :selected_icon_color, :size_change_interval, :size_constraints, :splash_color, :splash_radius, :style, :tooltip, :top, :url, :visible, :visual_density, :width, :on_animation_end, :on_blur, :on_click, :on_focus, :on_hover, :on_long_press, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            adaptive = props[:adaptive]
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
            bottom = props[:bottom]
            col = props[:col]
            data = props[:data]
            disabled = props[:disabled]
            disabled_color = props[:disabled_color]
            enable_feedback = props[:enable_feedback]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            focus_color = props[:focus_color]
            height = props[:height]
            highlight_color = props[:highlight_color]
            hover_color = props[:hover_color]
            icon = props[:icon]
            icon_color = props[:icon_color]
            icon_size = props[:icon_size]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            mouse_cursor = props[:mouse_cursor]
            offset = props[:offset]
            opacity = props[:opacity]
            padding = props[:padding]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            selected = props[:selected]
            selected_icon = props[:selected_icon]
            selected_icon_color = props[:selected_icon_color]
            size_change_interval = props[:size_change_interval]
            size_constraints = props[:size_constraints]
            splash_color = props[:splash_color]
            splash_radius = props[:splash_radius]
            style = props[:style]
            tooltip = props[:tooltip]
            top = props[:top]
            url = props[:url]
            visible = props[:visible]
            visual_density = props[:visual_density]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_click = props[:on_click]
            on_focus = props[:on_focus]
            on_hover = props[:on_hover]
            on_long_press = props[:on_long_press]
            on_size_change = props[:on_size_change]
            alignment = "center" if alignment.nil?
            autofocus = false if autofocus.nil?
            icon_size = 24 if icon_size.nil?
            padding = { "all" => 8 } if padding.nil?
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
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
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_color] = disabled_color unless disabled_color.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
            props[:highlight_color] = highlight_color unless highlight_color.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:icon] = icon unless icon.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:icon_size] = icon_size unless icon_size.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected] = selected unless selected.nil?
            props[:selected_icon] = selected_icon unless selected_icon.nil?
            props[:selected_icon_color] = selected_icon_color unless selected_icon_color.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:size_constraints] = size_constraints unless size_constraints.nil?
            props[:splash_color] = splash_color unless splash_color.nil?
            props[:splash_radius] = splash_radius unless splash_radius.nil?
            props[:style] = style unless style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:visual_density] = visual_density unless visual_density.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_hover] = on_hover unless on_hover.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
