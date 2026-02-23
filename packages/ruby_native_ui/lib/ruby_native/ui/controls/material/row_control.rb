# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class RowControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "row", id: id, **props)
        end
      end
    end
  end
end
