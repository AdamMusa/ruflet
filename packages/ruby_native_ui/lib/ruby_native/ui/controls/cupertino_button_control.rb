# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoButtonControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_button", id: id, **props)
        end
      end
    end
  end
end
