# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ViewControl < Ruflet::Control
          TYPE = "view".freeze
          WIRE = "View".freeze

          def initialize(id: nil, align: nil, animate_align: nil, animate_margin: nil, animate_offset: nil, animate_opacity: nil, animate_position: nil, animate_rotation: nil, animate_scale: nil, animate_size: nil, appbar: nil, aspect_ratio: nil, auto_scroll: nil, badge: nil, bgcolor: nil, bottom: nil, bottom_appbar: nil, can_pop: nil, col: nil, controls: nil, data: nil, decoration: nil, disabled: nil, drawer: nil, end_drawer: nil, expand: nil, expand_loose: nil, floating_action_button: nil, floating_action_button_location: nil, foreground_decoration: nil, fullscreen_dialog: nil, height: nil, horizontal_alignment: nil, key: nil, left: nil, margin: nil, navigation_bar: nil, offset: nil, opacity: nil, padding: nil, right: nil, rotate: nil, route: nil, rtl: nil, scale: nil, scroll: nil, scroll_interval: nil, services: nil, size_change_interval: nil, spacing: nil, tooltip: nil, top: nil, vertical_alignment: nil, visible: nil, width: nil, on_animation_end: nil, on_confirm_pop: nil, on_scroll: nil, on_size_change: nil)
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
            props[:appbar] = appbar unless appbar.nil?
            props[:aspect_ratio] = aspect_ratio unless aspect_ratio.nil?
            props[:auto_scroll] = auto_scroll unless auto_scroll.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:bottom] = bottom unless bottom.nil?
            props[:bottom_appbar] = bottom_appbar unless bottom_appbar.nil?
            props[:can_pop] = can_pop unless can_pop.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:decoration] = decoration unless decoration.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:drawer] = drawer unless drawer.nil?
            props[:end_drawer] = end_drawer unless end_drawer.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:floating_action_button] = floating_action_button unless floating_action_button.nil?
            props[:floating_action_button_location] = floating_action_button_location unless floating_action_button_location.nil?
            props[:foreground_decoration] = foreground_decoration unless foreground_decoration.nil?
            props[:fullscreen_dialog] = fullscreen_dialog unless fullscreen_dialog.nil?
            props[:height] = height unless height.nil?
            props[:horizontal_alignment] = horizontal_alignment unless horizontal_alignment.nil?
            props[:key] = key unless key.nil?
            props[:left] = left unless left.nil?
            props[:margin] = margin unless margin.nil?
            props[:navigation_bar] = navigation_bar unless navigation_bar.nil?
            props[:offset] = offset unless offset.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:right] = right unless right.nil?
            props[:rotate] = rotate unless rotate.nil?
            props[:route] = route unless route.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:scale] = scale unless scale.nil?
            props[:scroll] = scroll unless scroll.nil?
            props[:scroll_interval] = scroll_interval unless scroll_interval.nil?
            props[:services] = services unless services.nil?
            props[:size_change_interval] = size_change_interval unless size_change_interval.nil?
            props[:spacing] = spacing unless spacing.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:top] = top unless top.nil?
            props[:vertical_alignment] = vertical_alignment unless vertical_alignment.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_animation_end] = on_animation_end unless on_animation_end.nil?
            props[:on_confirm_pop] = on_confirm_pop unless on_confirm_pop.nil?
            props[:on_scroll] = on_scroll unless on_scroll.nil?
            props[:on_size_change] = on_size_change unless on_size_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
