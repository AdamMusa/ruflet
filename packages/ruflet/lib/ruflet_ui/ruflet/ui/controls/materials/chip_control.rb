# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ChipControl < Ruflet::Control
          TYPE = "chip".freeze
          WIRE = "Chip".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, border_side: nil, bottom: nil, check_color: nil, clip_behavior: nil, col: nil, color: nil, data: nil, delete_drawer_animation_style: nil, delete_icon: nil, delete_icon_color: nil, delete_icon_size_constraints: nil, delete_icon_tooltip: nil, disabled: nil, disabled_color: nil, elevation: nil, elevation_on_click: nil, enable_animation_style: nil, expand: nil, expand_loose: nil, height: nil, key: nil, label: nil, label_padding: nil, label_text_style: nil, leading: nil, leading_drawer_animation_style: nil, leading_size_constraints: nil, left: nil, margin: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, select_animation_style: nil, selected: nil, selected_color: nil, selected_shadow_color: nil, shadow_color: nil, shape: nil, show_checkmark: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, visual_density: nil, width: nil, on_animation_end: nil, on_blur: nil, on_click: nil, on_delete: nil, on_focus: nil, on_select: nil, on_size_change: nil)
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
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:border_side] = border_side unless border_side.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:check_color] = check_color unless check_color.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:delete_drawer_animation_style] = delete_drawer_animation_style unless delete_drawer_animation_style.nil?
            props[:delete_icon] = delete_icon unless delete_icon.nil?
            props[:delete_icon_color] = delete_icon_color unless delete_icon_color.nil?
            props[:delete_icon_size_constraints] = delete_icon_size_constraints unless delete_icon_size_constraints.nil?
            props[:delete_icon_tooltip] = delete_icon_tooltip unless delete_icon_tooltip.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_color] = disabled_color unless disabled_color.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:elevation_on_click] = elevation_on_click unless elevation_on_click.nil?
            props[:enable_animation_style] = enable_animation_style unless enable_animation_style.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_padding] = label_padding unless label_padding.nil?
            props[:label_text_style] = label_text_style unless label_text_style.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_drawer_animation_style] = leading_drawer_animation_style unless leading_drawer_animation_style.nil?
            props[:leading_size_constraints] = leading_size_constraints unless leading_size_constraints.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:select_animation_style] = select_animation_style unless select_animation_style.nil?
            props[:selected] = selected unless selected.nil?
            props[:selected_color] = selected_color unless selected_color.nil?
            props[:selected_shadow_color] = selected_shadow_color unless selected_shadow_color.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:shape] = shape unless shape.nil?
            props[:show_checkmark] = show_checkmark unless show_checkmark.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:visual_density] = visual_density unless visual_density.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_delete] = on_delete unless on_delete.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_select] = on_select unless on_select.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
