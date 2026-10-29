# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TableRowControl < Ruflet::Control
          TYPE = "tablerow".freeze
          WIRE = "TableRow".freeze

          KEYWORDS = [:bgcolor, :controls, :data, :key, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            bgcolor = props[:bgcolor]
            controls = props[:controls]
            data = props[:data]
            key = props[:key]
            visible = props[:visible]

            props = {}
            props[:bgcolor] = bgcolor unless bgcolor.nil?
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
