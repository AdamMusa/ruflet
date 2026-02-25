# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class FilledButtonControl < ButtonControl
        def initialize(id: nil, **props)
          super(type: "filledbutton", id: id, **props)
        end
      end
    end
  end
end
