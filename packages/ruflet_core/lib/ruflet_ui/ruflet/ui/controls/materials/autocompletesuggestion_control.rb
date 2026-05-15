# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class AutoCompleteSuggestionControl < Ruflet::Control
          TYPE = "autocompletesuggestion".freeze
          WIRE = "AutoCompleteSuggestion".freeze

          def initialize(id: nil, key: nil, value: nil)
            raise ArgumentError, "auto_complete_suggestion requires key or value" if key.nil? && value.nil?

            key ||= value
            value ||= key

            props = {}
            props[:key] = key unless key.nil?
            props[:value] = value unless value.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
