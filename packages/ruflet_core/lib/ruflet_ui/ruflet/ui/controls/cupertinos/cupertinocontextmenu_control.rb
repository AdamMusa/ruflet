# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoContextMenuControl < Ruflet::Control
          TYPE = "cupertinocontextmenu".freeze
          WIRE = "CupertinoContextMenu".freeze

          def initialize(id: nil, actions: nil, adaptive: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, enable_haptic_feedback: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil)
            props = {}
            props[:actions] = actions unless actions.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:enable_haptic_feedback] = enable_haptic_feedback unless enable_haptic_feedback.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
