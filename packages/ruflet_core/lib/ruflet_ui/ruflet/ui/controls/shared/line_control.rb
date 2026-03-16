# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class LineControl < Ruflet::Control
          TYPE = "line".freeze
          WIRE = "Line".freeze

          def initialize(id: nil, data: nil, key: nil, paint: nil, x1: nil, x2: nil, y1: nil, y2: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:x1] = x1 unless x1.nil?
            props[:x2] = x2 unless x2.nil?
            props[:y1] = y1 unless y1.nil?
            props[:y2] = y2 unless y2.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
