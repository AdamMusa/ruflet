# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      class CupertinoDialogActionControl < Ruflet::Control
        def initialize(id: nil, **props)
          super(type: "cupertino_dialog_action", id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          if mapped.key?(:text) || mapped.key?("text")
            value = mapped.key?(:text) ? mapped.delete(:text) : mapped.delete("text")
            mapped[:content] = value unless mapped.key?(:content) || mapped.key?("content")
          end
          mapped
        end
      end
    end
  end
end
