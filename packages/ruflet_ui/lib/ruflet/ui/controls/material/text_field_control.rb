# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class TextFieldControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "textfield", id: id, **props)
        end
      end
    end
  end
end
