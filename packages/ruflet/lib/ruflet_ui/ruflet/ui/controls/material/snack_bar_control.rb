# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class SnackBarControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "snackbar", id: id, **props)
        end
      end
    end
  end
end
