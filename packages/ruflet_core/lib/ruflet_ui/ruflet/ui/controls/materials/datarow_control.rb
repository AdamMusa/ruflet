# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataRowControl < Ruflet::Control
          TYPE = "datarow".freeze
          WIRE = "DataRow".freeze

          def initialize(id: nil, badge: nil, cells: nil, col: nil, color: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, key: nil, opacity: nil, rtl: nil, selected: nil, tooltip: nil, visible: nil, on_long_press: nil, on_select_change: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:cells] = cells unless cells.nil?
            props[:col] = col unless col.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:key] = key unless key.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:selected] = selected unless selected.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_long_press] = on_long_press unless on_long_press.nil?
            props[:on_select_change] = on_select_change unless on_select_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
