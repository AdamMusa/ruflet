# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class ConnectivityControl < Ruflet::Control
          TYPE = "connectivity".freeze
          WIRE = "Connectivity".freeze

          def initialize(id: nil, data: nil, key: nil, on_change: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_change] = on_change unless on_change.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
