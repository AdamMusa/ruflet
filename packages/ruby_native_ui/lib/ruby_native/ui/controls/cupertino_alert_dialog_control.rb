# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoAlertDialogControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_alert_dialog", id: id, **props)
        end
      end
    end
  end
end
