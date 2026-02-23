# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class RadioGroupControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "radiogroup", id: id, **props)
        end
      end
    end
  end
end
