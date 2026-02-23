# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class DragTargetControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "dragtarget", id: id, **props)
        end
      end
    end
  end
end
