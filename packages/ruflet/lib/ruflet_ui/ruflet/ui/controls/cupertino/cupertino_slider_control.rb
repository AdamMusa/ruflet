# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoSliderControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_slider", id: id, **props)
        end
      end
    end
  end
end
