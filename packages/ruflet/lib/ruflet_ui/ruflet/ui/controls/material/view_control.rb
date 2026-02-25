# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class ViewControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "view", id: id, **props)
        end
      end
    end
  end
end
