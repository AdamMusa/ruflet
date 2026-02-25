# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class DraggableControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "draggable", id: id, **props)
        end
      end
    end
  end
end
