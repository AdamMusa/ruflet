# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class TabBarViewControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "tabbarview", id: id, **props)
        end
      end
    end
  end
end
