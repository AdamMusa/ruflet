# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class MenuBarControl < Ruflet::Control
          TYPE = "menubar".freeze
          WIRE = "MenuBar".freeze

          def initialize(id: nil, badge: nil, clip_behavior: nil, col: nil, controls: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, style: nil, tooltip: nil, visible: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:clip_behavior] = clip_behavior unless clip_behavior.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:style] = style unless style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
