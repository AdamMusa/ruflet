# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoListTileControl < Ruflet::Control
          TYPE = "cupertinolisttile".freeze
          WIRE = "CupertinoListTile".freeze

          def initialize(id: nil, additional_info: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bgcolor_activated: nil, bottom: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, leading: nil, leading_size: nil, leading_to_title: nil, left: nil, margin: nil, notched: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, subtitle: nil, title: nil, toggle_inputs: nil, tooltip: nil, top: nil, trailing: nil, url: nil, visible: nil, width: nil, on_animation_end: nil, on_click: nil, on_size_change: nil)
            props = {}
            props[:additional_info] = additional_info unless additional_info.nil?
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
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bgcolor_activated] = bgcolor_activated unless bgcolor_activated.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_size] = leading_size unless leading_size.nil?
            props[:leading_to_title] = leading_to_title unless leading_to_title.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:notched] = notched unless notched.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:subtitle] = subtitle unless subtitle.nil?
            props[:title] = title unless title.nil?
            props[:toggle_inputs] = toggle_inputs unless toggle_inputs.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:trailing] = trailing unless trailing.nil?
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
