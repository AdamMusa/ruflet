# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SnackBarControl < Ruflet::Control
          TYPE = "snackbar".freeze
          WIRE = "SnackBar".freeze

          KEYWORDS = [:action, :action_overflow_threshold, :adaptive, :badge, :behavior, :bgcolor, :clip_behavior, :close_icon_color, :col, :content, :data, :disabled, :dismiss_direction, :duration, :elevation, :expand, :expand_loose, :key, :margin, :opacity, :open, :padding, :persist, :rtl, :shape, :show_close_icon, :tooltip, :visible, :width, :on_action, :on_dismiss, :on_visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            action = props[:action]
            action_overflow_threshold = props[:action_overflow_threshold]
            adaptive = props[:adaptive]
            badge = props[:badge]
            behavior = props[:behavior]
            bgcolor = props[:bgcolor]
            clip_behavior = props[:clip_behavior]
            close_icon_color = props[:close_icon_color]
            col = props[:col]
            content = props[:content]
            data = props[:data]
            disabled = props[:disabled]
            dismiss_direction = props[:dismiss_direction]
            duration = props[:duration]
            elevation = props[:elevation]
            expand = props[:expand]
            expand_loose = props[:expand_loose]
            key = props[:key]
            margin = props[:margin]
            opacity = props[:opacity]
            open = props[:open]
            padding = props[:padding]
            persist = props[:persist]
            rtl = props[:rtl]
            shape = props[:shape]
            show_close_icon = props[:show_close_icon]
            tooltip = props[:tooltip]
            visible = props[:visible]
            width = props[:width]
            on_action = props[:on_action]
            on_dismiss = props[:on_dismiss]
            on_visible = props[:on_visible]
            raise ArgumentError, "snack_bar requires content" if content.nil?

            props = {}
            props[:action] = action unless action.nil?
            props[:action_overflow_threshold] = action_overflow_threshold unless action_overflow_threshold.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:behavior] = behavior unless behavior.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:close_icon_color] = close_icon_color unless close_icon_color.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:dismiss_direction] = dismiss_direction unless dismiss_direction.nil?
            props[:duration] = duration unless duration.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:margin] = margin unless margin.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:padding] = padding unless padding.nil?
            props[:persist] = persist unless persist.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:shape] = shape unless shape.nil?
            props[:show_close_icon] = show_close_icon unless show_close_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:width] = width unless width.nil?
            props[:on_action] = on_action unless on_action.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_visible] = on_visible unless on_visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
