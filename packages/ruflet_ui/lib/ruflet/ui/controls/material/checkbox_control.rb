# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CheckboxControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "checkbox", id: id, **props)
        end
      end
    end
  end
end
