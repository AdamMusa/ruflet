# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class NavigationBarControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "navigationbar", id: id, **props)
        end
      end
    end
  end
end
