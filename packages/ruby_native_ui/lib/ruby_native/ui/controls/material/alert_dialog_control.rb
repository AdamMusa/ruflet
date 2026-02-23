# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class AlertDialogControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "alertdialog", id: id, **props)
        end
      end
    end
  end
end
