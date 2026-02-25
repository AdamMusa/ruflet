# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class IconButtonControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "iconbutton", id: id, **props)
        end
      end
    end
  end
end
