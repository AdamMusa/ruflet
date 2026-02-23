# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoDialogActionControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_dialog_action", id: id, **props)
        end
      end
    end
  end
end
