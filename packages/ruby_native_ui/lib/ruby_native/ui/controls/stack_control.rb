# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class StackControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "stack", id: id, **props)
        end
      end
    end
  end
end
