# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class ShakeDetectorControl < Ruflet::Control
          TYPE = "shakedetector".freeze
          WIRE = "ShakeDetector".freeze

          def initialize(id: nil, data: nil, key: nil, minimum_shake_count: nil, shake_count_reset_time_ms: nil, shake_slop_time_ms: nil, shake_threshold_gravity: nil, on_shake: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:minimum_shake_count] = minimum_shake_count unless minimum_shake_count.nil?
            props[:shake_count_reset_time_ms] = shake_count_reset_time_ms unless shake_count_reset_time_ms.nil?
            props[:shake_slop_time_ms] = shake_slop_time_ms unless shake_slop_time_ms.nil?
            props[:shake_threshold_gravity] = shake_threshold_gravity unless shake_threshold_gravity.nil?
            props[:on_shake] = on_shake unless on_shake.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
