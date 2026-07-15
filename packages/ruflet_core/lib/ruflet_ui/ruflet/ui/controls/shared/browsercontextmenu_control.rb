# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BrowserContextMenuControl < Ruflet::Control
          TYPE = "browsercontextmenu".freeze
          WIRE = "BrowserContextMenu".freeze

          def initialize(id: nil, data: nil, disabled: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:disabled] = disabled unless disabled.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def disable(timeout: 10, on_result: nil)
            props["disabled"] = true
            runtime_page&.invoke(self, "disable_menu", timeout: timeout, on_result: on_result)
          end

          def enable(timeout: 10, on_result: nil)
            props["disabled"] = false
            runtime_page&.invoke(self, "enable_menu", timeout: timeout, on_result: on_result)
          end
        end
      end
    end
  end
end
