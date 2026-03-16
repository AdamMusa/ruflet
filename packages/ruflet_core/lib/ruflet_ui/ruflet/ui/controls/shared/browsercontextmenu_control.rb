# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BrowserContextMenuControl < Ruflet::Control
          TYPE = "browsercontextmenu".freeze
          WIRE = "BrowserContextMenu".freeze

          def initialize(id: nil, data: nil, key: nil)
            props = {}
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
