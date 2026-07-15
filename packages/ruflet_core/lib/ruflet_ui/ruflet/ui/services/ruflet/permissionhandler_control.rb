# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class PermissionHandlerControl < Ruflet::Control
          TYPE = "permissionhandler".freeze
          WIRE = "PermissionHandler".freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def get_status(permission, timeout: 10, on_result: nil)
            invoke_permission_handler(
              "get_status",
              args: { "permission" => normalize_service_value(permission) },
              timeout: timeout,
              on_result: on_result
            )
          end

          def request(permission, timeout: 10, on_result: nil)
            invoke_permission_handler(
              "request",
              args: { "permission" => normalize_service_value(permission) },
              timeout: timeout,
              on_result: on_result
            )
          end

          def open_app_settings(timeout: 10, on_result: nil)
            invoke_permission_handler("open_app_settings", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_permission_handler(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def normalize_service_value(value)
            return value.to_s if value.is_a?(Symbol)

            value.respond_to?(:to_h) ? value.to_h.transform_keys(&:to_s) : value
          end
        end
      end
    end
  end
end
