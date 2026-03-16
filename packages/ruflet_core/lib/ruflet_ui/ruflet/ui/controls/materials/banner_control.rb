# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BannerControl < Ruflet::Control
          TYPE = "banner".freeze
          WIRE = "Banner".freeze

          def initialize(id: nil, actions: nil, adaptive: nil, badge: nil, bgcolor: nil, col: nil, content: nil, content_padding: nil, content_text_style: nil, data: nil, disabled: nil, divider_color: nil, elevation: nil, expand: nil, expand_loose: nil, force_actions_below: nil, key: nil, leading: nil, leading_padding: nil, margin: nil, min_action_bar_height: nil, opacity: nil, open: nil, rtl: nil, shadow_color: nil, tooltip: nil, visible: nil, on_dismiss: nil, on_visible: nil)
            props = {}
            props[:actions] = actions unless actions.nil?
            props[:adaptive] = adaptive unless adaptive.nil?
            props[:badge] = badge unless badge.nil?
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:content_padding] = content_padding unless content_padding.nil?
            props[:content_text_style] = content_text_style unless content_text_style.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:divider_color] = divider_color unless divider_color.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:force_actions_below] = force_actions_below unless force_actions_below.nil?
            props[:key] = key unless key.nil?
            props[:leading] = leading unless leading.nil?
            props[:leading_padding] = leading_padding unless leading_padding.nil?
            props[:margin] = margin unless margin.nil?
            props[:min_action_bar_height] = min_action_bar_height unless min_action_bar_height.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:open] = open unless open.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:shadow_color] = shadow_color unless shadow_color.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_dismiss] = on_dismiss unless on_dismiss.nil?
            props[:on_visible] = on_visible unless on_visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
