# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CircleControl < Ruflet::Control
          TYPE = "circle".freeze
          WIRE = "Circle".freeze

          def initialize(id: nil, data: nil, key: nil, paint: nil, radius: nil, x: nil, y: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:radius] = radius unless radius.nil?
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
