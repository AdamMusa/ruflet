# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoNavigationBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_navigation_bar", id: id, **props)
        end
      end
    end
  end
end
