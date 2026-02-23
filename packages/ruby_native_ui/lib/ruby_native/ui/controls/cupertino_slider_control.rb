# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoSliderControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_slider", id: id, **props)
        end
      end
    end
  end
end
