# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DropdownOptionControl < Ruflet::Control
          TYPE = "dropdownoption".freeze
          WIRE = "DropdownOption".freeze

          def initialize(id: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, leading_icon: nil, opacity: nil, rtl: nil, style: nil, text: nil, tooltip: nil, trailing_icon: nil, visible: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:leading_icon] = leading_icon unless leading_icon.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:style] = style unless style.nil?
            props[:text] = text unless text.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:trailing_icon] = trailing_icon unless trailing_icon.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
