# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class NavigationBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "navigationbar", id: id, **props)
        end
      end
    end
  end
end
