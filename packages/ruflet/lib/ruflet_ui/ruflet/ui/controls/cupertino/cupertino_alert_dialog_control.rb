# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoAlertDialogControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_alert_dialog", id: id, **props)
        end
      end
    end
  end
end
