# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class TesterControl < Ruflet::Control
          TYPE = "tester".freeze
          WIRE = "Tester".freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def pump(duration: nil, timeout: 10, on_result: nil)
            invoke_tester("pump", args: compact_args("duration" => duration), timeout: timeout, on_result: on_result)
          end

          def pump_and_settle(duration: nil, timeout: 10, on_result: nil)
            invoke_tester("pump_and_settle", args: compact_args("duration" => duration), timeout: timeout, on_result: on_result)
          end

          def find_by_text(text, timeout: 10, on_result: nil)
            invoke_tester("find_by_text", args: { "text" => text }, timeout: timeout, on_result: on_result)
          end

          def find_by_text_containing(pattern, timeout: 10, on_result: nil)
            invoke_tester("find_by_text_containing", args: { "pattern" => pattern }, timeout: timeout, on_result: on_result)
          end

          def find_by_key(key, timeout: 10, on_result: nil)
            invoke_tester("find_by_key", args: { "key" => key }, timeout: timeout, on_result: on_result)
          end

          def find_by_tooltip(value, timeout: 10, on_result: nil)
            invoke_tester("find_by_tooltip", args: { "value" => value }, timeout: timeout, on_result: on_result)
          end

          def find_by_icon(icon, timeout: 10, on_result: nil)
            invoke_tester("find_by_icon", args: { "icon" => normalize_service_value(icon) }, timeout: timeout, on_result: on_result)
          end

          def take_screenshot(name, timeout: 10, on_result: nil)
            invoke_tester("take_screenshot", args: { "name" => name }, timeout: timeout, on_result: on_result)
          end

          %w[tap mouse_click mouse_double_click right_mouse_click long_press mouse_hover].each do |method_name|
            define_method(method_name) do |finder_id = nil, finder_index: nil, timeout: 10, on_result: nil|
              invoke_tester(
                method_name,
                args: compact_args("finder_id" => finder_id, "finder_index" => finder_index),
                timeout: timeout,
                on_result: on_result
              )
            end
          end

          %w[tap_at mouse_click_at mouse_double_click_at right_mouse_click_at].each do |method_name|
            define_method(method_name) do |offset = nil, timeout: 10, on_result: nil|
              invoke_tester(method_name, args: compact_args("offset" => offset), timeout: timeout, on_result: on_result)
            end
          end

          def drag(finder_id, offset, finder_index: nil, timeout: 10, on_result: nil)
            invoke_tester(
              "drag",
              args: compact_args("finder_id" => finder_id, "finder_index" => finder_index, "offset" => offset),
              timeout: timeout,
              on_result: on_result
            )
          end

          def drag_from(start, offset, timeout: 10, on_result: nil)
            invoke_tester(
              "drag_from",
              args: compact_args("start" => start, "offset" => offset),
              timeout: timeout,
              on_result: on_result
            )
          end

          def enter_text(finder_id, text, finder_index: nil, timeout: 10, on_result: nil)
            invoke_tester(
              "enter_text",
              args: compact_args("finder_id" => finder_id, "finder_index" => finder_index, "text" => text),
              timeout: timeout,
              on_result: on_result
            )
          end

          def teardown(timeout: 10, on_result: nil)
            invoke_tester("teardown", timeout: timeout, on_result: on_result)
          end

          private

          def invoke_tester(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(self, method_name, args: args, timeout: timeout, on_result: on_result)
          end

          def compact_args(hash)
            hash.each_with_object({}) do |(key, value), result|
              result[key] = normalize_service_value(value) unless value.nil?
            end
          end

          def normalize_service_value(value)
            case value
            when Array
              value.map { |item| normalize_service_value(item) }
            when Hash
              value.transform_keys(&:to_s).each_with_object({}) do |(key, item), result|
                result[key] = normalize_service_value(item) unless item.nil?
              end
            else
              value.respond_to?(:to_h) ? normalize_service_value(value.to_h) : value
            end
          end
        end
      end
    end
  end
end
