# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class BatteryControl < Ruflet::Control
          TYPE = "battery".freeze
          WIRE = "Battery".freeze

          def initialize(id: nil, data: nil, key: nil, on_state_change: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_state_change] = on_state_change unless on_state_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
