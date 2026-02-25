# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class GestureDetectorControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "gesturedetector", id: id, **props)
        end
      end
    end
  end
end
