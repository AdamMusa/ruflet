# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataColumnControl < Ruflet::Control
          TYPE = "datacolumn".freeze
          WIRE = "DataColumn".freeze

          def initialize(id: nil, badge: nil, col: nil, data: nil, disabled: nil, expand: nil, expand_loose: nil, heading_row_alignment: nil, key: nil, label: nil, numeric: nil, opacity: nil, rtl: nil, tooltip: nil, visible: nil, on_sort: nil)
            props = {}
            props[:badge] = badge unless badge.nil?
            props[:col] = col unless col.nil?
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:expand] = expand unless expand.nil?
            props[:expand_loose] = expand_loose unless expand_loose.nil?
            props[:heading_row_alignment] = heading_row_alignment unless heading_row_alignment.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:numeric] = numeric unless numeric.nil?
            props[:opacity] = opacity unless opacity.nil?
            props[:rtl] = rtl unless rtl.nil?
            props[:tooltip] = tooltip unless tooltip.nil?
            props[:visible] = visible unless visible.nil?
            props[:on_sort] = on_sort unless on_sort.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
