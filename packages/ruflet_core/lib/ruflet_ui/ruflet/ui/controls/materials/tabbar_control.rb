# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TabBarControl < Ruflet::Control
          TYPE = "tabbar".freeze
          WIRE = "TabBar".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, col: nil, data: nil, disabled: nil, divider_color: nil, divider_height: nil, enable_feedback: nil, expand: nil, expand_loose: nil, height: nil, indicator: nil, indicator_animation: nil, indicator_color: nil, indicator_size: nil, indicator_thickness: nil, key: nil, label_color: nil, label_padding: nil, label_text_style: nil, left: nil, margin: nil, mouse_cursor: nil, offset: nil, opacity: nil, overlay_color: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, scrollable: nil, secondary: nil, size_change_interval: nil, splash_border_radius: nil, tab_alignment: nil, tabs: nil, tooltip: nil, top: nil, unselected_label_color: nil, unselected_label_text_style: nil, visible: nil, width: nil, on_animation_end: nil, on_click: nil, on_hover: nil, on_size_change: nil)
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
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_color] = divider_color unless divider_color.nil?
            props[:divider_height] = divider_height unless divider_height.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:indicator] = indicator unless indicator.nil?
            props[:indicator_animation] = indicator_animation unless indicator_animation.nil?
            props[:indicator_color] = indicator_color unless indicator_color.nil?
            props[:indicator_size] = indicator_size unless indicator_size.nil?
            props[:indicator_thickness] = indicator_thickness unless indicator_thickness.nil?
            props[:key] = key unless key.nil?
            props[:label_color] = label_color unless label_color.nil?
            props[:label_padding] = label_padding unless label_padding.nil?
            props[:label_text_style] = label_text_style unless label_text_style.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:overlay_color] = overlay_color unless overlay_color.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:scrollable] = scrollable unless scrollable.nil?
            props[:secondary] = secondary unless secondary.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:splash_border_radius] = splash_border_radius unless splash_border_radius.nil?
            props[:tab_alignment] = tab_alignment unless tab_alignment.nil?
            props[:tabs] = tabs unless tabs.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:unselected_label_color] = unselected_label_color unless unselected_label_color.nil?
            props[:unselected_label_text_style] = unselected_label_text_style unless unselected_label_text_style.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_hover] = on_hover unless on_hover.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
