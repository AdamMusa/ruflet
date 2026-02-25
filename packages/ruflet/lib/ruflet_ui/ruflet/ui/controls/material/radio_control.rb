# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class RadioControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "radio", id: id, **props)
        end
      end
    end
  end
end
