# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class MarkdownControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "markdown", id: id, **props)
        end
      end
    end
  end
end
