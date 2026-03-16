# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PointsControl < Ruflet::Control
          TYPE = "points".freeze
          WIRE = "Points".freeze

          def initialize(id: nil, data: nil, key: nil, paint: nil, point_mode: nil, points: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            props[:point_mode] = point_mode unless point_mode.nil?
            props[:points] = points unless points.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
