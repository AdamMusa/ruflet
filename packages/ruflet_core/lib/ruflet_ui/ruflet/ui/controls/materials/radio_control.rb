# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RadioControl < Ruflet::Control
          TYPE = "radio".freeze
          WIRE = "Radio".freeze

          def initialize(id: nil, active_color: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bottom: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, fill_color: nil, focus_color: nil, height: nil, hover_color: nil, key: nil, label: nil, label_position: nil, label_style: nil, left: nil, margin: nil, mouse_cursor: nil, offset: nil, opacity: nil, overlay_color: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, splash_radius: nil, toggleable: nil, tooltip: nil, top: nil, value: nil, visible: nil, visual_density: nil, width: nil, on_animation_end: nil, on_blur: nil, on_focus: nil, on_size_change: nil)
            props = {}
            props[:active_color] = active_color unless active_color.nil?
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
            props[:autofocus] = autofocus unless autofocus.nil?
            props[:badge] = badge unless badge.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:fill_color] = fill_color unless fill_color.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:height] = height unless height.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:label_position] = label_position unless label_position.nil?
            props[:label_style] = label_style unless label_style.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:overlay_color] = overlay_color unless overlay_color.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:splash_radius] = splash_radius unless splash_radius.nil?
            props[:toggleable] = toggleable unless toggleable.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:value] = value unless value.nil?
            props[:visible] = visible unless visible.nil?
            props[:visual_density] = visual_density unless visual_density.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
