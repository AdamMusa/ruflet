# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ElevatedButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "elevatedbutton", id: id, **props)
        end
      end
    end
  end
end
