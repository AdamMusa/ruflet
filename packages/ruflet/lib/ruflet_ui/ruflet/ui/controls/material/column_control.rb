# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class ColumnControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "column", id: id, **props)
        end
      end
    end
  end
end
