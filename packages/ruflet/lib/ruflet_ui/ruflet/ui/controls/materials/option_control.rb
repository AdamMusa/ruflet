# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class OptionControl < Ruflet::Control
          TYPE = "option".freeze
          WIRE = "Option".freeze

          def initialize(id: nil, alignment: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, text: nil, text_style: nil, tooltip: nil, visible: nil, on_click: nil)
            props = {}
            props[:alignment] = alignment unless alignment.nil?
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:text] = text unless text.nil?
            props[:text_style] = text_style unless text_style.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_click] = on_click unless on_click.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
