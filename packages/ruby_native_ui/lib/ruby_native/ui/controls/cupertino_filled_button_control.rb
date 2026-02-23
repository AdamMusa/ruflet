# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoFilledButtonControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_filled_button", id: id, **props)
        end
      end
    end
  end
end
