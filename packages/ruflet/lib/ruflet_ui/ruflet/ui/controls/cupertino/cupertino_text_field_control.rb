# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoTextFieldControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_text_field", id: id, **props)
        end
      end
    end
  end
end
