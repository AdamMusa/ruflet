# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoNavigationBarControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_navigation_bar", id: id, **props)
        end
      end
    end
  end
end
