# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoTextFieldControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_text_field", id: id, **props)
        end
      end
    end
  end
end
