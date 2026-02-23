# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ContainerControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "container", id: id, **props)
        end
      end
    end
  end
end
