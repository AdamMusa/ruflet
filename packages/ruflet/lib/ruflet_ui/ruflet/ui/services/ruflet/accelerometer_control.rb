# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class AccelerometerControl < Ruflet::Control
          TYPE = "accelerometer".freeze
          WIRE = "Accelerometer".freeze

          def initialize(id: nil, cancel_on_error: nil, data: nil, enabled: nil, interval: nil, key: nil, on_error: nil, on_reading: nil)
            props = {}
            props[:cancel_on_error] = cancel_on_error unless cancel_on_error.nil?
            props[:data] = data unless data.nil?
            props[:enabled] = enabled unless enabled.nil?
            props[:interval] = interval unless interval.nil?
            props[:key] = key unless key.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_reading] = on_reading unless on_reading.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
