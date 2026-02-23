# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ViewControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "view", id: id, **props)
        end
      end
    end
  end
end
