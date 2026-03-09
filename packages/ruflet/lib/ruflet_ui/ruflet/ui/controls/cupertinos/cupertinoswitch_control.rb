# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoSwitchControl < Ruflet::Control
          TYPE = "cupertinoswitch".freeze
          WIRE = "CupertinoSwitch".freeze

          def initialize(id: nil, active_thumb_image_src: nil, active_track_color: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bottom: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, focus_color: nil, height: nil, inactive_thumb_color: nil, inactive_thumb_image_src: nil, inactive_track_color: nil, key: nil, label: nil, label_position: nil, left: nil, margin: nil, off_label_color: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, thumb_color: nil, thumb_icon: nil, tooltip: nil, top: nil, track_outline_color: nil, track_outline_width: nil, value: nil, visible: nil, width: nil, on_animation_end: nil, on_blur: nil, on_change: nil, on_focus: nil, on_image_error: nil, on_label_color: nil, on_size_change: nil)
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
