# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PopupMenuButtonControl < Ruflet::Control
          TYPE = "popupmenubutton".freeze
          WIRE = "PopupMenuButton".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bottom: nil, clip_behavior: nil, col: nil, content: nil, data: nil, disabled: nil, elevation: nil, enable_feedback: nil, expand: nil, expand_loose: nil, height: nil, icon: nil, icon_color: nil, icon_size: nil, items: nil, key: nil, left: nil, margin: nil, menu_padding: nil, menu_position: nil, offset: nil, opacity: nil, padding: nil, popup_animation_style: nil, right: nil, rotate: nil, rtl: nil, scale: nil, shadow_color: nil, shape: nil, size_change_interval: nil, size_constraints: nil, splash_radius: nil, style: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_cancel: nil, on_open: nil, on_select: nil, on_size_change: nil)
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
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:icon_color] = icon_color unless icon_color.nil?
            props[:icon_size] = icon_size unless icon_size.nil?
            props[:items] = items unless items.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:menu_padding] = menu_padding unless menu_padding.nil?
            props[:menu_position] = menu_position unless menu_position.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:popup_animation_style] = popup_animation_style unless popup_animation_style.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:shape] = shape unless shape.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:size_constraints] = size_constraints unless size_constraints.nil?
            props[:splash_radius] = splash_radius unless splash_radius.nil?
            props[:style] = style unless style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_cancel] = on_cancel unless on_cancel.nil?
            props[:on_open] = on_open unless on_open.nil?
            props[:on_select] = on_select unless on_select.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
