# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TextFieldControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "textfield", id: id, **props)
        end
      end
    end
  end
end
