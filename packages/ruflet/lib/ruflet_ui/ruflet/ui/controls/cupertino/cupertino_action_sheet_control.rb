# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoActionSheetControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_action_sheet", id: id, **props)
        end
      end
    end
  end
end
