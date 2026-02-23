# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TextControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "text", id: id, **props)
        end
      end
    end
  end
end
