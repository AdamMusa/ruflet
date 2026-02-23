# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class AppBarControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "appbar", id: id, **props)
        end
      end
    end
  end
end
