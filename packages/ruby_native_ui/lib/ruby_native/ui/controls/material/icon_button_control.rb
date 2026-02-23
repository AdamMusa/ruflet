# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class IconButtonControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "iconbutton", id: id, **props)
        end
      end
    end
  end
end
