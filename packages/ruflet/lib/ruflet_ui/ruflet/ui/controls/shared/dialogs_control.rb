# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DialogsControl < Ruflet::Control
          TYPE = "dialogs".freeze
          WIRE = "Dialogs".freeze

          def initialize(id: nil, controls: nil, data: nil, key: nil)
            props = {}
            props[:controls] = controls unless controls.nil?
            props[:data] = data unless data.nil?
            props[:key] = key unless key.nil?
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
