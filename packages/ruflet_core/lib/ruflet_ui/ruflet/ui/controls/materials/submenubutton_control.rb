# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SubmenuButtonControl < Ruflet::Control
          TYPE = "submenubutton".freeze
          WIRE = "SubmenuButton".freeze

          KEYWORDS = [:align, :alignment_offset, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :clip_behavior, :col, :content, :controls, :data, :disabled, :expand, :expand_loose, :height, :key, :leading, :left, :margin, :menu_style, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :style, :tooltip, :top, :trailing, :visible, :width, :on_animation_end, :on_blur, :on_close, :on_focus, :on_hover, :on_open, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            align = props[:align]
            alignment_offset = props[:alignment_offset]
            animate_align = props[:animate_align]
            animate_margin = props[:animate_margin]
            animate_offset = props[:animate_offset]
            animate_opacity = props[:animate_opacity]
            animate_position = props[:animate_position]
            animate_rotation = props[:animate_rotation]
            animate_scale = props[:animate_scale]
            animate_size = props[:animate_size]
            aspect_ratio = props[:aspect_ratio]
            badge = props[:badge]
            bottom = props[:bottom]
            clip_behavior = props[:clip_behavior]
            col = props[:col]
            content = props[:content]
            controls = props[:controls]
            data = props[:data]
            disabled = props[:disabled]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            height = props[:height]
            key = props[:key]
            leading = props[:leading]
            left = props[:left]
            margin = props[:margin]
            menu_style = props[:menu_style]
            offset = props[:offset]
            opacity = props[:opacity]
            right = props[:right]
            rotate = props[:rotate]
            rtl = props[:rtl]
            scale = props[:scale]
            size_change_interval = props[:size_change_interval]
            style = props[:style]
            tooltip = props[:tooltip]
            top = props[:top]
            trailing = props[:trailing]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_blur = props[:on_blur]
            on_close = props[:on_close]
            on_focus = props[:on_focus]
            on_hover = props[:on_hover]
            on_open = props[:on_open]
            on_size_change = props[:on_size_change]
            clip_behavior = "none" if clip_behavior.nil?

            props = {}
            props[:align] = align unless align.nil?
            props[:alignment_offset] = alignment_offset unless alignment_offset.nil?
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
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:menu_style] = menu_style unless menu_style.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:style] = style unless style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing] = trailing unless trailing.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_blur] = on_blur unless on_blur.nil?
            props[:on_close] = on_close unless on_close.nil?
            props[:on_focus] = on_focus unless on_focus.nil?
            props[:on_hover] = on_hover unless on_hover.nil?
            props[:on_open] = on_open unless on_open.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
