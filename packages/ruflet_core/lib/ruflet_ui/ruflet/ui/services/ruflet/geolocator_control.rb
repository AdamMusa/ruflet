# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class GeolocatorControl < Ruflet::Control
          TYPE = "geolocator".freeze
          WIRE = "Geolocator".freeze

          def initialize(id: nil, configuration: nil, data: nil, key: nil, on_error: nil, on_position_change: nil)
            props = {}
            props[:configuration] = configuration unless configuration.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            props[:on_error] = on_error unless on_error.nil?
            props[:on_position_change] = on_position_change unless on_position_change.nil?
            super(type: TYPE, id: id, **props)
          end

          %w[get_last_known_position get_permission_status is_location_service_enabled open_app_settings open_location_settings request_permission].each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_service(method_name, timeout: timeout, on_result: on_result)
            end
          end

          def distance_between(start_latitude, start_longitude, end_latitude, end_longitude, timeout: 10, on_result: nil)
            invoke_service(
              "distance_between",
              args: {
                "start_latitude" => start_latitude,
                "start_longitude" => start_longitude,
                "end_latitude" => end_latitude,
                "end_longitude" => end_longitude
              },
              timeout: timeout,
              on_result: on_result
            )
          end

          def get_current_position(configuration: nil, timeout: 10, on_result: nil)
            # The public Ruflet/Flet API calls this value `configuration`, while
            # the Flutter service currently reads it from the `settings` invoke
            # argument.
            args = configuration.nil? ? nil : { "settings" => normalize_value(configuration) }
            invoke_service("get_current_position", args: args, timeout: timeout, on_result: on_result)
          end

          private

          def invoke_service(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def normalize_value(value)
            case value
            when Array then value.map { |item| normalize_value(item) }
            when Hash
              value.each_with_object({}) { |(key, item), result| result[key.to_s] = normalize_value(item) unless item.nil? }
            else
              value.respond_to?(:to_h) ? normalize_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
