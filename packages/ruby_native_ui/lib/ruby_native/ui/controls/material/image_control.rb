# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ImageControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "image", id: id, **props)
        end
      end
    end
  end
end
