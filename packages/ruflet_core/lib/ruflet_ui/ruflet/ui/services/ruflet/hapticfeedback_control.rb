# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class HapticFeedbackControl < Ruflet::Control
          TYPE = "hapticfeedback".freeze
          WIRE = "HapticFeedback".freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
