# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PathControl < Ruflet::Control
          TYPE = "path".freeze
          WIRE = "Path".freeze

          def initialize(id: nil, data: nil, elements: nil, key: nil, paint: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:elements] = elements unless elements.nil?
            props[:key] = key unless key.nil?
            props[:paint] = paint unless paint.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
