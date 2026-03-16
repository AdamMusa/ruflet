# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ArcControl < Ruflet::Control
          TYPE = "arc".freeze
          WIRE = "Arc".freeze

          def initialize(id: nil, data: nil, height: nil, key: nil, paint: nil, start_angle: nil, sweep_angle: nil, use_center: nil, width: nil, x: nil, y: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:height] = height unless height.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:start_angle] = start_angle unless start_angle.nil?
            props[:sweep_angle] = sweep_angle unless sweep_angle.nil?
            props[:use_center] = use_center unless use_center.nil?
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
