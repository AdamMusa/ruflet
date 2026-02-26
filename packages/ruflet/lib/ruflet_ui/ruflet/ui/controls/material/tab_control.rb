# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class TabControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tab", id: id, **props)
        end
      end
    end
  end
end
