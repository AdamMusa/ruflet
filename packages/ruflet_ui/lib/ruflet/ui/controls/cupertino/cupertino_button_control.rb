# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_button", id: id, **props)
        end
      end
    end
  end
end
