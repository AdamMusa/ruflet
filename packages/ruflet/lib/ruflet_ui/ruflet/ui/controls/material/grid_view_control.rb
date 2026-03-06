# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class GridViewControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "gridview", id: id, **props)
        end
      end
    end
  end
end
