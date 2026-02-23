# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ColumnControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "column", id: id, **props)
        end
      end
    end
  end
end
