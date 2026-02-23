# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class ButtonControl < RubyNative::Control
        def initialize(id: nil, type: "button", **props)
          super(type: type, id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          if mapped.key?(:text) || mapped.key?("text")
            value = mapped.delete(:text) || mapped.delete("text")
            mapped[:content] = value unless mapped.key?(:content) || mapped.key?("content")
          end
          mapped
        end
      end
    end
  end
end
