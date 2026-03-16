# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SelectionAreaControl < Ruflet::Control
          TYPE = "selectionarea".freeze
          WIRE = "SelectionArea".freeze

          def initialize(id: nil, badge: nil, col: nil, content: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil, on_change: nil)
            props = {}
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
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_change] = on_change unless on_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
