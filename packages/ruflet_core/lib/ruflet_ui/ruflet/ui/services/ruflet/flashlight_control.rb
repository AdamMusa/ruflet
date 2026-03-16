# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class FlashlightControl < Ruflet::Control
          TYPE = "flashlight".freeze
          WIRE = "Flashlight".freeze

          def initialize(id: nil, data: nil, key: nil, on_error: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_error] = on_error unless on_error.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
