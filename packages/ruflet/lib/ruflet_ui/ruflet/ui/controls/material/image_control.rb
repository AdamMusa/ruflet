# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class ImageControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "image", id: id, **props)
        end
      end
    end
  end
end
