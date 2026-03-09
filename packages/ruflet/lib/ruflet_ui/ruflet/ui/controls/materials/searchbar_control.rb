# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SearchBarControl < Ruflet::Control
          TYPE = "searchbar".freeze
          WIRE = "SearchBar".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bar_bgcolor: nil, bar_border_side: nil, bar_elevation: nil, bar_hint_text: nil, bar_hint_text_style: nil, bar_leading: nil, bar_overlay_color: nil, bar_padding: nil, bar_scroll_padding: nil, bar_shadow_color: nil, bar_shape: nil, bar_size_constraints: nil, bar_text_style: nil, bar_trailing: nil, bottom: nil, capitalization: nil, col: nil, controls: nil, data: nil, disabled: nil, divider_color: nil, expand: nil, expand_loose: nil, full_screen: nil, height: nil, key: nil, keyboard_type: nil, left: nil, margin: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, shrink_wrap: nil, size_change_interval: nil, tooltip: nil, top: nil, value: nil, view_bar_padding: nil, view_bgcolor: nil, view_elevation: nil, view_header_height: nil, view_header_text_style: nil, view_hint_text: nil, view_hint_text_style: nil, view_leading: nil, view_padding: nil, view_shape: nil, view_side: nil, view_size_constraints: nil, view_trailing: nil, visible: nil, width: nil, on_animation_end: nil, on_blur: nil, on_change: nil, on_focus: nil, on_size_change: nil, on_submit: nil, on_tap: nil, on_tap_outside_bar: nil)
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
            props[:bar_bgcolor] = bar_bgcolor unless bar_bgcolor.nil?
            props[:bar_border_side] = bar_border_side unless bar_border_side.nil?
            props[:bar_elevation] = bar_elevation unless bar_elevation.nil?
            props[:bar_hint_text] = bar_hint_text unless bar_hint_text.nil?
            props[:bar_hint_text_style] = bar_hint_text_style unless bar_hint_text_style.nil?
            props[:bar_leading] = bar_leading unless bar_leading.nil?
            props[:bar_overlay_color] = bar_overlay_color unless bar_overlay_color.nil?
            props[:bar_padding] = bar_padding unless bar_padding.nil?
            props[:bar_scroll_padding] = bar_scroll_padding unless bar_scroll_padding.nil?
            props[:bar_shadow_color] = bar_shadow_color unless bar_shadow_color.nil?
            props[:bar_shape] = bar_shape unless bar_shape.nil?
            props[:bar_size_constraints] = bar_size_constraints unless bar_size_constraints.nil?
            props[:bar_text_style] = bar_text_style unless bar_text_style.nil?
            props[:bar_trailing] = bar_trailing unless bar_trailing.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:capitalization] = capitalization unless capitalization.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_color] = divider_color unless divider_color.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:full_screen] = full_screen unless full_screen.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:keyboard_type] = keyboard_type unless keyboard_type.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:shrink_wrap] = shrink_wrap unless shrink_wrap.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:value] = value unless value.nil?
            props[:view_bar_padding] = view_bar_padding unless view_bar_padding.nil?
            props[:view_bgcolor] = view_bgcolor unless view_bgcolor.nil?
            props[:view_elevation] = view_elevation unless view_elevation.nil?
            props[:view_header_height] = view_header_height unless view_header_height.nil?
            props[:view_header_text_style] = view_header_text_style unless view_header_text_style.nil?
            props[:view_hint_text] = view_hint_text unless view_hint_text.nil?
            props[:view_hint_text_style] = view_hint_text_style unless view_hint_text_style.nil?
            props[:view_leading] = view_leading unless view_leading.nil?
            props[:view_padding] = view_padding unless view_padding.nil?
            props[:view_shape] = view_shape unless view_shape.nil?
            props[:view_side] = view_side unless view_side.nil?
            props[:view_size_constraints] = view_size_constraints unless view_size_constraints.nil?
            props[:view_trailing] = view_trailing unless view_trailing.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            props[:on_submit] = on_submit unless on_submit.nil?
            props[:on_tap] = on_tap unless on_tap.nil?
            props[:on_tap_outside_bar] = on_tap_outside_bar unless on_tap_outside_bar.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
