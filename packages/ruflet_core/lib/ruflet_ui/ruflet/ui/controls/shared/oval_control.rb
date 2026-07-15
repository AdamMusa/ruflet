# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class OvalControl < Ruflet::Control
          TYPE = "oval".freeze
          WIRE = "Oval".freeze

          def initialize(id: nil, data: nil, height: nil, key: nil, paint: nil, width: nil, x: nil, y: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:width] = width unless width.nil?
            props[:x] = x unless x.nil?
            props[:y] = y unless y.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
