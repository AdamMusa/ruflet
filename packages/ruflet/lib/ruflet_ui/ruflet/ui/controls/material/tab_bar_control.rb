# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class TabBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "tabbar", id: id, **props)
        end
      end
    end
  end
end
