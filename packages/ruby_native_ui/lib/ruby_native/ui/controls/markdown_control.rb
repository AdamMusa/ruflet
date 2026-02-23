# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class MarkdownControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "markdown", id: id, **props)
        end
      end
    end
  end
end
