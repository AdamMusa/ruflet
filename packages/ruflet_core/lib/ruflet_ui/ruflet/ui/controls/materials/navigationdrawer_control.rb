# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class NavigationDrawerControl < Ruflet::Control
          TYPE = "navigationdrawer".freeze
          WIRE = "NavigationDrawer".freeze

          def initialize(id: nil, adaptive: nil, badge: nil, bgcolor: nil, col: nil, controls: nil, data: nil, disabled: nil, elevation: nil, expand: nil, expand_loose: nil, indicator_color: nil, indicator_shape: nil, key: nil, opacity: nil, rtl: nil, selected_index: nil, shadow_color: nil, tile_padding: nil, tooltip: nil, visible: nil, on_change: nil, on_dismiss: nil)
            props = {}
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:col] = col unless col.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:indicator_color] = indicator_color unless indicator_color.nil?
            props[:indicator_shape] = indicator_shape unless indicator_shape.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:selected_index] = selected_index unless selected_index.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:tile_padding] = tile_padding unless tile_padding.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_change] = on_change unless on_change.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
