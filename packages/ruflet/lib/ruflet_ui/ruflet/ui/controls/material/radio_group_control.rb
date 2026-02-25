# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class RadioGroupControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "radiogroup", id: id, **props)
        end
      end
    end
  end
end
