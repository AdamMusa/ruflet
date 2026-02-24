# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class SnackBarControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "snackbar", id: id, **props)
        end
      end
    end
  end
end
