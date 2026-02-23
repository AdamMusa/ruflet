# frozen_string_literal: true

module RubyNative
  module UI
    module Controls
      class FloatingActionButtonControl < RubyNative::Control
        def initialize(id: nil, **props)
          super(type: "floatingactionbutton", id: id, **props)
        end

        private

        def preprocess_props(props)
          normalized = props.dup

          # Accept both correct and common-misspelled foreground color keys.
          if !normalized.key?(:color) && !normalized.key?("color")
            fg = normalized.delete(:foreground_color) || normalized.delete("foreground_color")
            fg ||= normalized.delete(:forground_color) || normalized.delete("forground_color")
            normalized[:color] = fg if fg
          end

          normalized
        end
      end
    end
  end
end
