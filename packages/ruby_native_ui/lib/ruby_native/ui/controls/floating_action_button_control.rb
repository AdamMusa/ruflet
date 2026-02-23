# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class FloatingActionButtonControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "floatingactionbutton", id: id, **props)
        end
      end
    end
  end
end
