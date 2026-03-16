# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PageletControl < Ruflet::Control
          TYPE = "pagelet".freeze
          WIRE = "Pagelet".freeze

          def initialize(id: nil, adaptive: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, appbar: nil, aspect_ratio: nil, badge: nil, bgcolor: nil, bottom: nil, bottom_appbar: nil, bottom_sheet: nil, col: nil, content: nil, data: nil, disabled: nil, drawer: nil, end_drawer: nil, expand: nil, expand_loose: nil, floating_action_button: nil, floating_action_button_location: nil, height: nil, key: nil, left: nil, margin: nil, navigation_bar: nil, offset: nil, opacity: nil, right: nil, rotate: nil, rtl: nil, scale: nil, size_change_interval: nil, tooltip: nil, top: nil, visible: nil, width: nil, on_animation_end: nil, on_size_change: nil)
            props = {}
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
            props[:appbar] = appbar unless appbar.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:bottom_appbar] = bottom_appbar unless bottom_appbar.nil?
            props[:bottom_sheet] = bottom_sheet unless bottom_sheet.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:drawer] = drawer unless drawer.nil?
            props[:end_drawer] = end_drawer unless end_drawer.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:floating_action_button] = floating_action_button unless floating_action_button.nil?
            props[:floating_action_button_location] = floating_action_button_location unless floating_action_button_location.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:navigation_bar] = navigation_bar unless navigation_bar.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
