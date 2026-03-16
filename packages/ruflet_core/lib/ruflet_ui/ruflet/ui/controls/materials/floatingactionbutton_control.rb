# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class FloatingActionButtonControl < Ruflet::Control
          TYPE = "floatingactionbutton".freeze
          WIRE = "FloatingActionButton".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, autofocus: nil, badge: nil, bgcolor: nil, bottom: nil, clip_behavior: nil, col: nil, content: nil, data: nil, disabled: nil, disabled_elevation: nil, elevation: nil, enable_feedback: nil, expand: nil, expand_loose: nil, focus_color: nil, focus_elevation: nil, foreground_color: nil, height: nil, highlight_elevation: nil, hover_color: nil, hover_elevation: nil, icon: nil, key: nil, left: nil, margin: nil, mini: nil, mouse_cursor: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, shape: nil, size_change_interval: nil, splash_color: nil, tooltip: nil, top: nil, url: nil, visible: nil, width: nil, on_animation_end: nil, on_click: nil, on_size_change: nil)
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
            props[:bottom] = bottom unless bottom.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:disabled_elevation] = disabled_elevation unless disabled_elevation.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:enable_feedback] = enable_feedback unless enable_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:focus_color] = focus_color unless focus_color.nil?
            props[:focus_elevation] = focus_elevation unless focus_elevation.nil?
            props[:foreground_color] = foreground_color unless foreground_color.nil?
            props[:height] = height unless height.nil?
            props[:highlight_elevation] = highlight_elevation unless highlight_elevation.nil?
            props[:hover_color] = hover_color unless hover_color.nil?
            props[:hover_elevation] = hover_elevation unless hover_elevation.nil?
            props[:icon] = icon unless icon.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:mini] = mini unless mini.nil?
            props[:mouse_cursor] = mouse_cursor unless mouse_cursor.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:shape] = shape unless shape.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:splash_color] = splash_color unless splash_color.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:url] = url unless url.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_click] = on_click unless on_click.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
