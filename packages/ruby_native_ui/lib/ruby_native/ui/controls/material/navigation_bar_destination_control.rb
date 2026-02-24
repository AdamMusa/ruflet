# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class NavigationBarDestinationControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "navigationbardestination", id: id, **props)
        end
      end
    end
  end
end
