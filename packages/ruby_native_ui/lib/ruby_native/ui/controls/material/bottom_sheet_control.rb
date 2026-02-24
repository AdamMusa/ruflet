# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class BottomSheetControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "bottomsheet", id: id, **props)
        end
      end
    end
  end
end
