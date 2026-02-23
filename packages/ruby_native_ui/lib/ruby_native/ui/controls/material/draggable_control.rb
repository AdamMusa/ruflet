# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class DraggableControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "draggable", id: id, **props)
        end
      end
    end
  end
end
