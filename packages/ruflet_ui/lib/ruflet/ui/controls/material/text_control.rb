# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class TextControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "text", id: id, **props)
        end
      end
    end
  end
end
