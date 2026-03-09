# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TabControl < Ruflet::Control
          TYPE = "tab".freeze
          WIRE = "Tab".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, icon: nil, icon_margin: nil, key: nil, label: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:icon] = icon unless icon.nil?
            props[:icon_margin] = icon_margin unless icon_margin.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
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
