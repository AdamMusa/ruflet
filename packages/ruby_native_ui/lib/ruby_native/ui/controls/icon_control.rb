# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class IconControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "icon", id: id, **props)
        end

        private

        def preprocess_props(props)
          mapped = props.dup
          if mapped.key?(:name) || mapped.key?("name")
            value = mapped.delete(:name) || mapped.delete("name")
            mapped[:icon] = value unless mapped.key?(:icon) || mapped.key?("icon")
          end
          mapped
        end
      end
    end
  end
end
