# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class RowControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "row", id: id, **props)
        end
      end
    end
  end
end
