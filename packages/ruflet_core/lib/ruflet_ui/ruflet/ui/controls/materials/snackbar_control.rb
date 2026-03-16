# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SnackBarControl < Ruflet::Control
          TYPE = "snackbar".freeze
          WIRE = "SnackBar".freeze

          def initialize(id: nil, action: nil, action_overflow_threshold: nil, adaptive: nil, badge: nil, behavior: nil, bgcolor: nil, clip_behavior: nil, close_icon_color: nil, col: nil, content: nil, data: nil, disabled: nil, dismiss_direction: nil, duration: nil, elevation: nil, expand: nil, expand_loose: nil, key: nil, margin: nil, opacity: nil, open: nil, padding: nil, persist: nil, rtl: nil, shape: nil, show_close_icon: nil, tooltip: nil, visible: nil, width: nil, on_action: nil, on_dismiss: nil, on_visible: nil)
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
