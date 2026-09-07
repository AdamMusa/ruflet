# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ServiceRegistryControl < Ruflet::Control
          TYPE = "serviceregistry".freeze
          WIRE = "ServiceRegistry".freeze

          KEYWORDS = [:_services, :services, :data, :key].freeze

          def initialize(id: nil, _services: nil, services: nil, data: nil, key: nil)
            props = {}
            mounted_services = _services.nil? ? services : _services
            props[:_services] = mounted_services unless mounted_services.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
