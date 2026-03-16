# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class NavigationRailDestinationControl < Ruflet::Control
          TYPE = "navigationraildestination".freeze
          WIRE = "NavigationRailDestination".freeze

          def initialize(id: nil, badge: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, icon: nil, indicator_color: nil, indicator_shape: nil, key: nil, label: nil, opacity: nil, padding: nil, rtl: nil, selected_icon: nil, tooltip: nil, visible: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:icon] = icon unless icon.nil?
            props[:indicator_color] = indicator_color unless indicator_color.nil?
            props[:indicator_shape] = indicator_shape unless indicator_shape.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:padding] = padding unless padding.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:selected_icon] = selected_icon unless selected_icon.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
