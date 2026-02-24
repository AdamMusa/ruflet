# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TabBarControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "tabbar", id: id, **props)
        end
      end
    end
  end
end
