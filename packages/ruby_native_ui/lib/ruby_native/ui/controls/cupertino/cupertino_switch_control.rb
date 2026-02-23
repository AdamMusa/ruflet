# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoSwitchControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_switch", id: id, **props)
        end
      end
    end
  end
end
