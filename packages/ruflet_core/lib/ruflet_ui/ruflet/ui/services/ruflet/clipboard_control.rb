# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class ClipboardControl < Ruflet::Control
          TYPE = "clipboard".freeze
          WIRE = "Clipboard".freeze
          KEYWORDS = [:data, :key].freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def set(value, timeout: 10, on_result: nil)
            invoke_service("set", args: { "data" => value.to_s }, timeout: timeout, on_result: on_result)
          end

          def get(timeout: 10, on_result: nil)
            invoke_service("get", timeout: timeout, on_result: on_result)
          end

          def set_image(value, timeout: 10, on_result: nil)
            invoke_service("set_image", args: { "data" => value }, timeout: timeout, on_result: on_result)
          end

          def get_image(timeout: 10, on_result: nil)
            invoke_service("get_image", timeout: timeout, on_result: on_result)
          end

          def set_files(files, timeout: 10, on_result: nil)
            invoke_service("set_files", args: { "files" => Array(files).map(&:to_s) }, timeout: timeout, on_result: on_result)
          end

          def get_files(timeout: 10, on_result: nil)
            invoke_service("get_files", timeout: timeout, on_result: on_result)
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
