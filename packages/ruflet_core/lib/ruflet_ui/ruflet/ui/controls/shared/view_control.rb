# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ViewControl < Ruflet::Control
          TYPE = "view".freeze
          WIRE = "View".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :appbar, :aspect_ratio, :auto_scroll, :badge, :bgcolor, :bottom, :bottom_appbar, :can_pop, :col, :controls, :data, :decoration, :disabled, :drawer, :end_drawer, :expand, :expand_loose, :floating_action_button, :floating_action_button_location, :foreground_decoration, :fullscreen_dialog, :height, :horizontal_alignment, :key, :left, :margin, :navigation_bar, :offset, :opacity, :padding, :right, :rotate, :route, :rtl, :scale, :scroll, :scroll_interval, :services, :size_change_interval, :spacing, :tooltip, :top, :vertical_alignment, :visible, :width, :on_animation_end, :on_confirm_pop, :on_scroll, :on_size_change].freeze

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
            appbar = props[:appbar]
            aspect_ratio = props[:aspect_ratio]
            auto_scroll = props[:auto_scroll]
            badge = props[:badge]
            bgcolor = props[:bgcolor]
            bottom = props[:bottom]
            bottom_appbar = props[:bottom_appbar]
            can_pop = props[:can_pop]
            col = props[:col]
            controls = props[:controls]
            data = props[:data]
            decoration = props[:decoration]
            disabled = props[:disabled]
            drawer = props[:drawer]
            end_drawer = props[:end_drawer]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            floating_action_button = props[:floating_action_button]
            floating_action_button_location = props[:floating_action_button_location]
            foreground_decoration = props[:foreground_decoration]
            fullscreen_dialog = props[:fullscreen_dialog]
            height = props[:height]
            horizontal_alignment = props[:horizontal_alignment]
            key = props[:key]
            left = props[:left]
            margin = props[:margin]
            navigation_bar = props[:navigation_bar]
            offset = props[:offset]
            opacity = props[:opacity]
            padding = props[:padding]
            right = props[:right]
            rotate = props[:rotate]
            route = props[:route]
            rtl = props[:rtl]
            scale = props[:scale]
            scroll = props[:scroll]
            scroll_interval = props[:scroll_interval]
            services = props[:services]
            size_change_interval = props[:size_change_interval]
            spacing = props[:spacing]
            tooltip = props[:tooltip]
            top = props[:top]
            vertical_alignment = props[:vertical_alignment]
            visible = props[:visible]
            width = props[:width]
            on_animation_end = props[:on_animation_end]
            on_confirm_pop = props[:on_confirm_pop]
            on_scroll = props[:on_scroll]
            on_size_change = props[:on_size_change]
            can_pop = true if can_pop.nil?
            fullscreen_dialog = false if fullscreen_dialog.nil?
            horizontal_alignment = "start" if horizontal_alignment.nil?
            padding = 10 if padding.nil?
            route = "/" if route.nil?
            spacing = 10 if spacing.nil?
            vertical_alignment = "start" if vertical_alignment.nil?

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
