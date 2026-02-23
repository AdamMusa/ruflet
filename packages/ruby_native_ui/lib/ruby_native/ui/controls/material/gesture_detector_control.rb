# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class GestureDetectorControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "gesturedetector", id: id, **props)
        end
      end
    end
  end
end
