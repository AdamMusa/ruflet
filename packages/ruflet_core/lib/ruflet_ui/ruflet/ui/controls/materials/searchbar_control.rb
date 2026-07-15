# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SearchBarControl < Ruflet::Control
          TYPE = "searchbar".freeze
          WIRE = "SearchBar".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bar_bgcolor, :bar_border_side, :bar_elevation, :bar_hint_text, :bar_hint_text_style, :bar_leading, :bar_overlay_color, :bar_padding, :bar_scroll_padding, :bar_shadow_color, :bar_shape, :bar_size_constraints, :bar_text_style, :bar_trailing, :bottom, :capitalization, :col, :controls, :data, :disabled, :divider_color, :expand, :expand_loose, :full_screen, :height, :key, :keyboard_type, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :shrink_wrap, :size_change_interval, :tooltip, :top, :value, :view_bar_padding, :view_bgcolor, :view_elevation, :view_header_height, :view_header_text_style, :view_hint_text, :view_hint_text_style, :view_leading, :view_padding, :view_shape, :view_side, :view_size_constraints, :view_trailing, :visible, :width, :on_animation_end, :on_blur, :on_change, :on_focus, :on_size_change, :on_submit, :on_tap, :on_tap_outside_bar].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
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
            bar_bgcolor = props[:bar_bgcolor]
            bar_border_side = props[:bar_border_side]
            bar_elevation = props[:bar_elevation]
            bar_hint_text = props[:bar_hint_text]
            bar_hint_text_style = props[:bar_hint_text_style]
            bar_leading = props[:bar_leading]
            bar_overlay_color = props[:bar_overlay_color]
            bar_padding = props[:bar_padding]
            bar_scroll_padding = props[:bar_scroll_padding]
            bar_shadow_color = props[:bar_shadow_color]
            bar_shape = props[:bar_shape]
            bar_size_constraints = props[:bar_size_constraints]
            bar_text_style = props[:bar_text_style]
            bar_trailing = props[:bar_trailing]
            bottom = props[:bottom]
            capitalization = props[:capitalization]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            divider_color = props[:divider_color]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            full_screen = props[:full_screen]
            height = props[:height]
            key = props[:key]
            keyboard_type = props[:keyboard_type]
            left = props[:left]
            margin = props[:margin]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            shrink_wrap = props[:shrink_wrap]
            size_change_interval = props[:size_change_interval]
            tooltip = props[:tooltip]
            top = props[:top]
            value = props[:value]
            view_bar_padding = props[:view_bar_padding]
            view_bgcolor = props[:view_bgcolor]
            view_elevation = props[:view_elevation]
            view_header_height = props[:view_header_height]
            view_header_text_style = props[:view_header_text_style]
            view_hint_text = props[:view_hint_text]
            view_hint_text_style = props[:view_hint_text_style]
            view_leading = props[:view_leading]
            view_padding = props[:view_padding]
            view_shape = props[:view_shape]
            view_side = props[:view_side]
            view_size_constraints = props[:view_size_constraints]
            view_trailing = props[:view_trailing]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_change = props[:on_change]
            on_focus = props[:on_focus]
            on_size_change = props[:on_size_change]
            on_submit = props[:on_submit]
            on_tap = props[:on_tap]
            on_tap_outside_bar = props[:on_tap_outside_bar]
            autofocus = false if autofocus.nil?
            full_screen = false if full_screen.nil?
            value = "" if value.nil?

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

          def open_view(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "open_view", timeout: timeout, on_result: on_result)
          end

          def close_view(text = nil, timeout: 10, on_result: nil)
            args = {}
            args["text"] = text unless text.nil?
            runtime_page&.invoke(self, "close_view", args: args, timeout: timeout, on_result: on_result)
          end

          def focus(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "focus", timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
