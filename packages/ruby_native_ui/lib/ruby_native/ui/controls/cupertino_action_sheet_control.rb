# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class CupertinoActionSheetControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_action_sheet", id: id, **props)
        end
      end
    end
  end
end
