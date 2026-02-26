# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class AlertDialogControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "alertdialog", id: id, **props)
        end
      end
    end
  end
end
