# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class Dropdown2Control < Ruflet::Control
          TYPE = "dropdownm2".freeze
          WIRE = "DropdownM2".freeze

          def initialize(id: nil, align: nil, align_label_with_hint: nil, alignment: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, border: nil, border_color: nil, border_radius: nil, border_width: nil, bottom: nil, col: nil, collapsed: nil, color: nil, content_padding: nil, counter: nil, counter_style: nil, data: nil, dense: nil, disabled: nil, disabled_hint_content: nil, elevation: nil, enable_feedback: nil, error: nil, error_max_lines: nil, error_style: nil, expand: nil, expand_loose: nil, fill_color: nil, filled: nil, fit_parent_size: nil, focus_color: nil, focused_bgcolor: nil, focused_border_color: nil, focused_border_width: nil, focused_color: nil, height: nil, helper: nil, helper_max_lines: nil, helper_style: nil, hint_content: nil, hint_fade_duration: nil, hint_max_lines: nil, hint_style: nil, hint_text: nil, hover_color: nil, icon: nil, item_height: nil, key: nil, label: nil, label_style: nil, left: nil, margin: nil, max_menu_height: nil, offset: nil, opacity: nil, options: nil, options_fill_horizontally: nil, padding: nil, prefix: nil, prefix_icon: nil, prefix_icon_size_constraints: nil, prefix_style: nil, right: nil, rotate: nil, rtl: nil, scale: nil, select_icon: nil, select_icon_disabled_color: nil, select_icon_enabled_color: nil, select_icon_size: nil, size_change_interval: nil, size_constraints: nil, suffix: nil, suffix_icon: nil, suffix_icon_size_constraints: nil, suffix_style: nil, text_size: nil, text_style: nil, text_vertical_align: nil, tooltip: nil, top: nil, value: nil, visible: nil, width: nil, on_animation_end: nil, on_blur: nil, on_change: nil, on_click: nil, on_focus: nil, on_size_change: nil)
            props = {}
            props[:align] = align unless align.nil?
            props[:align_label_with_hint] = align_label_with_hint unless align_label_with_hint.nil?
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
            props[:border] = border unless border.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:border_width] = border_width unless border_width.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:collapsed] = collapsed unless collapsed.nil?
            props[:color] = color unless color.nil?
            props[:content_padding] = content_padding unless content_padding.nil?
            props[:counter] = counter unless counter.nil?
            props[:counter_style] = counter_style unless counter_style.nil?
            props[:data] = data unless data.nil?
            props[:dense] = dense unless dense.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_hint_content] = disabled_hint_content unless disabled_hint_content.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:error] = error unless error.nil?
            props[:error_max_lines] = error_max_lines unless error_max_lines.nil?
            props[:error_style] = error_style unless error_style.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:filled] = filled unless filled.nil?
            props[:fit_parent_size] = fit_parent_size unless fit_parent_size.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:focused_bgcolor] = focused_bgcolor unless focused_bgcolor.nil?
            props[:focused_border_color] = focused_border_color unless focused_border_color.nil?
            props[:focused_border_width] = focused_border_width unless focused_border_width.nil?
            props[:focused_color] = focused_color unless focused_color.nil?
            props[:height] = height unless height.nil?
            props[:helper] = helper unless helper.nil?
            props[:helper_max_lines] = helper_max_lines unless helper_max_lines.nil?
            props[:helper_style] = helper_style unless helper_style.nil?
            props[:hint_content] = hint_content unless hint_content.nil?
            props[:hint_fade_duration] = hint_fade_duration unless hint_fade_duration.nil?
            props[:hint_max_lines] = hint_max_lines unless hint_max_lines.nil?
            props[:hint_style] = hint_style unless hint_style.nil?
            props[:hint_text] = hint_text unless hint_text.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:icon] = icon unless icon.nil?
            props[:item_height] = item_height unless item_height.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_style] = label_style unless label_style.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:max_menu_height] = max_menu_height unless max_menu_height.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:options] = options unless options.nil?
            props[:options_fill_horizontally] = options_fill_horizontally unless options_fill_horizontally.nil?
            props[:padding] = padding unless padding.nil?
            props[:prefix] = prefix unless prefix.nil?
            props[:prefix_icon] = prefix_icon unless prefix_icon.nil?
            props[:prefix_icon_size_constraints] = prefix_icon_size_constraints unless prefix_icon_size_constraints.nil?
            props[:prefix_style] = prefix_style unless prefix_style.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:select_icon] = select_icon unless select_icon.nil?
            props[:select_icon_disabled_color] = select_icon_disabled_color unless select_icon_disabled_color.nil?
            props[:select_icon_enabled_color] = select_icon_enabled_color unless select_icon_enabled_color.nil?
            props[:select_icon_size] = select_icon_size unless select_icon_size.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:size_constraints] = size_constraints unless size_constraints.nil?
            props[:suffix] = suffix unless suffix.nil?
            props[:suffix_icon] = suffix_icon unless suffix_icon.nil?
            props[:suffix_icon_size_constraints] = suffix_icon_size_constraints unless suffix_icon_size_constraints.nil?
            props[:suffix_style] = suffix_style unless suffix_style.nil?
            props[:text_size] = text_size unless text_size.nil?
            props[:text_style] = text_style unless text_style.nil?
            props[:text_vertical_align] = text_vertical_align unless text_vertical_align.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
