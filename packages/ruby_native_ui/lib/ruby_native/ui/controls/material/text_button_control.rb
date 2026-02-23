# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TextButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "textbutton", id: id, **props)
        end
      end
    end
  end
end
