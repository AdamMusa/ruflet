# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CheckboxControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "checkbox", id: id, **props)
        end
      end
    end
  end
end
