# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BrowserContextMenuControl < Ruflet::Control
          TYPE = "browsercontextmenu".freeze
          WIRE = "BrowserContextMenu".freeze

          def initialize(id: nil, data: nil, key: nil)
            @disabled = false
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end

          def enable(timeout: 10, on_result: nil)
            result = runtime_page&.invoke(self, "enable_menu", timeout: timeout, on_result: on_result)
            @disabled = false
            result
          end

          def disable(timeout: 10, on_result: nil)
            result = runtime_page&.invoke(self, "disable_menu", timeout: timeout, on_result: on_result)
            @disabled = true
            result
          end

          def disabled = @disabled
          def disabled? = @disabled
        end
      end
    end
  end
end
