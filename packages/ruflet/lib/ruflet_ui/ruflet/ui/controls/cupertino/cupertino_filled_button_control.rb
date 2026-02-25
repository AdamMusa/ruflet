# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoFilledButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_filled_button", id: id, **props)
        end
      end
    end
  end
end
