# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SubmenuButtonControl < Ruflet::Control
          TYPE = "submenubutton".freeze
          WIRE = "SubmenuButton".freeze

          def initialize(id: nil, align: nil, alignment_offset: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bottom: nil, clip_behavior: nil, col: nil, content: nil, controls: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, leading: nil, left: nil, margin: nil, menu_style: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, style: nil, tooltip: nil, top: nil, trailing: nil, visible: nil, width: nil, on_animation_end: nil, on_blur: nil, on_close: nil, on_focus: nil, on_hover: nil, on_open: nil, on_size_change: nil)
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
