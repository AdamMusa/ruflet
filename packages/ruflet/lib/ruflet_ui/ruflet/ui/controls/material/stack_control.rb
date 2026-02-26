# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class StackControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "stack", id: id, **props)
        end
      end
    end
  end
end
