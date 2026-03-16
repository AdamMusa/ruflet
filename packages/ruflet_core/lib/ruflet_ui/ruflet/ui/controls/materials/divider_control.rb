# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DividerControl < Ruflet::Control
          TYPE = "divider".freeze
          WIRE = "Divider".freeze

          def initialize(id: nil, badge: nil, col: nil, color: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, height: nil, key: nil, leading_indent: nil, opacity: nil, radius: nil, rtl: nil, thickness: nil, tooltip: nil, trailing_indent: nil, visible: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:leading_indent] = leading_indent unless leading_indent.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:radius] = radius unless radius.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:thickness] = thickness unless thickness.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:trailing_indent] = trailing_indent unless trailing_indent.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
