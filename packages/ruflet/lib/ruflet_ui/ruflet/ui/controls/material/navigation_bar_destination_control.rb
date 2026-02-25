# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class NavigationBarDestinationControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "navigationbardestination", id: id, **props)
        end
      end
    end
  end
end
