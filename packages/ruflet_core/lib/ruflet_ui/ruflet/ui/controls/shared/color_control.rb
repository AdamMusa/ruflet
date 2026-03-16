# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ColorControl < Ruflet::Control
          TYPE = "color".freeze
          WIRE = "Color".freeze

          def initialize(id: nil, blend_mode: nil, color: nil, data: nil, key: nil)
            props = {}
            props[:blend_mode] = blend_mode unless blend_mode.nil?
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
