# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class StepControl < Ruflet::Control
          # TYPE is the registry key used for lookups; it is deliberately not
          # "step" (D-6). The wire type stays "Step".
          TYPE = "stepper_step".freeze
          WIRE = "Step".freeze

          KEYWORDS = [:content, :data, :is_active, :key, :label, :state, :subtitle, :title, :visible].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?
            content = props[:content]
            data = props[:data]
            is_active = props[:is_active]
            key = props[:key]
            label = props[:label]
            state = props[:state]
            subtitle = props[:subtitle]
            title = props[:title]
            visible = props[:visible]
            raise ArgumentError, "stepper_step requires title" if title.nil?

            props = {}
            props[:content] = content unless content.nil?
            props[:data] = data unless data.nil?
            props[:is_active] = is_active unless is_active.nil?
            props[:key] = key unless key.nil?
            props[:label] = label unless label.nil?
            props[:state] = state unless state.nil?
            props[:subtitle] = subtitle unless subtitle.nil?
            props[:title] = title unless title.nil?
            props[:visible] = visible unless visible.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
