# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DropdownControl < Ruflet::Control
          TYPE = "dropdown".freeze
          WIRE = "Dropdown".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, border: nil, border_color: nil, border_radius: nil, border_width: nil, bottom: nil, capitalization: nil, col: nil, color: nil, content_padding: nil, data: nil, dense: nil, disabled: nil, editable: nil, elevation: nil, enable_filter: nil, enable_search: nil, error_style: nil, error_text: nil, expand: nil, expand_loose: nil, expanded_insets: nil, fill_color: nil, filled: nil, focused_border_color: nil, focused_border_width: nil, height: nil, helper_style: nil, helper_text: nil, hint_style: nil, hint_text: nil, hover_color: nil, input_filter: nil, key: nil, label: nil, label_style: nil, leading_icon: nil, left: nil, margin: nil, menu_height: nil, menu_style: nil, menu_width: nil, offset: nil, opacity: nil, options: nil, right: nil, rotate: nil, rtl: nil, scale: nil, selected_suffix: nil, selected_trailing_icon: nil, size_change_interval: nil, text: nil, text_align: nil, text_size: nil, text_style: nil, tooltip: nil, top: nil, trailing_icon: nil, value: nil, visible: nil, width: nil, on_animation_end: nil, on_blur: nil, on_focus: nil, on_select: nil, on_size_change: nil, on_text_change: nil)
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
            props[:border] = border unless border.nil?
            props[:border_color] = border_color unless border_color.nil?
            props[:border_radius] = border_radius unless border_radius.nil?
            props[:border_width] = border_width unless border_width.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:capitalization] = capitalization unless capitalization.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:content_padding] = content_padding unless content_padding.nil?
            props[:data] = data unless data.nil?
            props[:dense] = dense unless dense.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:editable] = editable unless editable.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:enable_filter] = enable_filter unless enable_filter.nil?
            props[:enable_search] = enable_search unless enable_search.nil?
            props[:error_style] = error_style unless error_style.nil?
            props[:error_text] = error_text unless error_text.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:expanded_insets] = expanded_insets unless expanded_insets.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:filled] = filled unless filled.nil?
            props[:focused_border_color] = focused_border_color unless focused_border_color.nil?
            props[:focused_border_width] = focused_border_width unless focused_border_width.nil?
            props[:height] = height unless height.nil?
            props[:helper_style] = helper_style unless helper_style.nil?
            props[:helper_text] = helper_text unless helper_text.nil?
            props[:hint_style] = hint_style unless hint_style.nil?
            props[:hint_text] = hint_text unless hint_text.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:input_filter] = input_filter unless input_filter.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_style] = label_style unless label_style.nil?
            props[:leading_icon] = leading_icon unless leading_icon.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:menu_height] = menu_height unless menu_height.nil?
            props[:menu_style] = menu_style unless menu_style.nil?
            props[:menu_width] = menu_width unless menu_width.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:options] = options unless options.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:selected_suffix] = selected_suffix unless selected_suffix.nil?
            props[:selected_trailing_icon] = selected_trailing_icon unless selected_trailing_icon.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:text] = text unless text.nil?
            props[:text_align] = text_align unless text_align.nil?
            props[:text_size] = text_size unless text_size.nil?
            props[:text_style] = text_style unless text_style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing_icon] = trailing_icon unless trailing_icon.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_select] = on_select unless on_select.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_text_change] = on_text_change unless on_text_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
