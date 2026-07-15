# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TextControl < Ruflet::Control
          TYPE = "text".freeze
          WIRE = "Text".freeze

          KEYWORDS = [:alignment, :bgcolor, :color, :data, :ellipsis, :enable_interactive_selection, :font_family, :font_family_fallback, :italic, :key, :max_lines, :max_width, :no_wrap, :overflow, :rotate, :selectable, :selection_cursor_color, :selection_cursor_height, :selection_cursor_width, :semantics_label, :show_selection_cursor, :size, :spans, :style, :text_align, :theme_style, :value, :weight, :x, :y, :on_selection_change, :on_tap].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
