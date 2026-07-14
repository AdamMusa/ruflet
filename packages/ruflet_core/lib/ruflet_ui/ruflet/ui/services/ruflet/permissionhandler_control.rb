# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class PermissionHandlerControl < Ruflet::Control
          TYPE = "permissionhandler".freeze
          WIRE = "PermissionHandler".freeze
          KEYWORDS = [:data, :key].freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def get_status(permission, timeout: 10, on_result: nil)
            invoke_service("get_status", args: { "permission" => permission }, timeout: timeout, on_result: on_result)
          end

          def request(permission, timeout: 10, on_result: nil)
            invoke_service("request", args: { "permission" => permission }, timeout: timeout, on_result: on_result)
          end

          def open_app_settings(timeout: 10, on_result: nil)
            invoke_service("open_app_settings", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_service(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
