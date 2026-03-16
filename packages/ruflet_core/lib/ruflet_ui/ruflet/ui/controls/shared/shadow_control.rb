# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ShadowControl < Ruflet::Control
          TYPE = "shadow".freeze
          WIRE = "Shadow".freeze

          def initialize(id: nil, color: nil, data: nil, elevation: nil, key: nil, path: nil, transparent_occluder: nil)
            props = {}
            props[:color] = color unless color.nil?
            props[:data] = data unless data.nil?
            props[:elevation] = elevation unless elevation.nil?
            props[:key] = key unless key.nil?
            props[:path] = path unless path.nil?
            props[:transparent_occluder] = transparent_occluder unless transparent_occluder.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
