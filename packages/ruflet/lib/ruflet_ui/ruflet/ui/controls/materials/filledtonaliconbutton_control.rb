# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class FilledTonalIconButtonControl < Ruflet::Control
          TYPE = "filledtonaliconbutton".freeze
          WIRE = "FilledTonalIconButton".freeze

          def initialize(id: nil, adaptive: nil, align: nil, alignment: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, bottom: nil, col: nil, data: nil, disabled: nil, disabled_color: nil, enable_feedback: nil, expand: nil, expand_loose: nil, focus_color: nil, height: nil, highlight_color: nil, hover_color: nil, icon: nil, icon_color: nil, icon_size: nil, key: nil, left: nil, margin: nil, mouse_cursor: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, selected: nil, selected_icon: nil, selected_icon_color: nil, size_change_interval: nil, size_constraints: nil, splash_color: nil, splash_radius: nil, style: nil, tooltip: nil, top: nil, url: nil, visible: nil, visual_density: nil, width: nil, on_animation_end: nil, on_blur: nil, on_click: nil, on_focus: nil, on_hover: nil, on_long_press: nil, on_size_change: nil)
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
