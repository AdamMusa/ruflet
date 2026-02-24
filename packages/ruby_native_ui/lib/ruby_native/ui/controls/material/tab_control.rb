# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TabControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "tab", id: id, **props)
        end
      end
    end
  end
end
