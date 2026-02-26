# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoSwitchControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_switch", id: id, **props)
        end
      end
    end
  end
end
