# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoSwitchControl < Ruflet::Control
          TYPE = "cupertinoswitch".freeze
          WIRE = "CupertinoSwitch".freeze

          KEYWORDS = [:active_thumb_image, :active_thumb_image_src, :active_track_color, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bottom, :col, :data, :disabled, :expand, :expand_loose, :focus_color, :height, :inactive_thumb_color, :inactive_thumb_image, :inactive_thumb_image_src, :inactive_track_color, :key, :label, :label_position, :left, :margin, :off_label_color, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :thumb_color, :thumb_icon, :tooltip, :top, :track_outline_color, :track_outline_width, :value, :visible, :width, :on_animation_end, :on_blur, :on_change, :on_focus, :on_image_error, :on_label_color, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            active_thumb_image = props[:active_thumb_image]
            active_thumb_image_src = props[:active_thumb_image_src]
            active_track_color = props[:active_track_color]
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
            bottom = props[:bottom]
            col = props[:col]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            focus_color = props[:focus_color]
            height = props[:height]
            inactive_thumb_color = props[:inactive_thumb_color]
            inactive_thumb_image = props[:inactive_thumb_image]
            inactive_thumb_image_src = props[:inactive_thumb_image_src]
            inactive_track_color = props[:inactive_track_color]
            key = props[:key]
            label = props[:label]
            label_position = props[:label_position]
            left = props[:left]
            margin = props[:margin]
            off_label_color = props[:off_label_color]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            thumb_color = props[:thumb_color]
            thumb_icon = props[:thumb_icon]
            tooltip = props[:tooltip]
            top = props[:top]
            track_outline_color = props[:track_outline_color]
            track_outline_width = props[:track_outline_width]
            value = props[:value]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_change = props[:on_change]
            on_focus = props[:on_focus]
            on_image_error = props[:on_image_error]
            on_label_color = props[:on_label_color]
            on_size_change = props[:on_size_change]
            active_thumb_image_src = active_thumb_image if active_thumb_image_src.nil?
            inactive_thumb_image_src = inactive_thumb_image if inactive_thumb_image_src.nil?
            autofocus = false if autofocus.nil?
            label_position = "right" if label_position.nil?
            value = false if value.nil?

            props = {}
            props[:active_thumb_image_src] = active_thumb_image_src unless active_thumb_image_src.nil?
            props[:active_track_color] = active_track_color unless active_track_color.nil?
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
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
            props[:inactive_thumb_color] = inactive_thumb_color unless inactive_thumb_color.nil?
            props[:inactive_thumb_image_src] = inactive_thumb_image_src unless inactive_thumb_image_src.nil?
            props[:inactive_track_color] = inactive_track_color unless inactive_track_color.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_position] = label_position unless label_position.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:off_label_color] = off_label_color unless off_label_color.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:thumb_color] = thumb_color unless thumb_color.nil?
            props[:thumb_icon] = thumb_icon unless thumb_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:track_outline_color] = track_outline_color unless track_outline_color.nil?
            props[:track_outline_width] = track_outline_width unless track_outline_width.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_image_error] = on_image_error unless on_image_error.nil?
            props[:on_label_color] = on_label_color unless on_label_color.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
