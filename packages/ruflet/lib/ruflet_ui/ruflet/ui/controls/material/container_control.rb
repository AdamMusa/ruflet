# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class ContainerControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "container", id: id, **props)
        end
      end
    end
  end
end
