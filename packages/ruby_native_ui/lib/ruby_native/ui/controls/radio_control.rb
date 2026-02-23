# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class RadioControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "radio", id: id, **props)
        end
      end
    end
  end
end
