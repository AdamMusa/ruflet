# frozen_string_literal: true

module Ruflet
  module UI
    module Services
      module RufletServicesComponents
        class SemanticsServiceControl < Ruflet::Control
          TYPE = "semanticsservice".freeze
          WIRE = "SemanticsService".freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def announce_message(message, rtl: false, assertiveness: "polite", timeout: 10, on_result: nil)
            runtime_page&.invoke(
              self,
              "announce_message",
              args: {
                "message" => message,
                "rtl" => rtl,
                "assertiveness" => assertiveness
              },
              timeout: timeout,
              on_result: on_result
            )
          end

          def announce_tooltip(message, timeout: 10, on_result: nil)
            runtime_page&.invoke(
              self,
              "announce_tooltip",
              args: { "message" => message },
              timeout: timeout,
              on_result: on_result
            )
          end

          def get_accessibility_features(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "get_accessibility_features", timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
