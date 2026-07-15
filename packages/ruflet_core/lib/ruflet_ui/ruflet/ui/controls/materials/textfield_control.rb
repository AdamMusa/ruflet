# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TextFieldControl < Ruflet::Control
          TYPE = "textfield".freeze
          WIRE = "TextField".freeze

          KEYWORDS = [:adaptive, :align, :align_label_with_hint, :always_call_on_tap, :animate_align, :animate_cursor_opacity, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autocorrect, :autofill_hints, :autofocus, :badge, :bgcolor, :border, :border_color, :border_radius, :border_width, :bottom, :can_request_focus, :can_reveal_password, :capitalization, :clip_behavior, :col, :collapsed, :color, :content_padding, :counter, :counter_style, :cursor_color, :cursor_error_color, :cursor_height, :cursor_radius, :cursor_width, :data, :dense, :disabled, :enable_ime_personalized_learning, :enable_interactive_selection, :enable_stylus_handwriting, :enable_suggestions, :error, :error_max_lines, :error_style, :expand, :expand_loose, :fill_color, :filled, :fit_parent_size, :focus_color, :focused_bgcolor, :focused_border_color, :focused_border_width, :focused_color, :height, :helper, :helper_max_lines, :helper_style, :hint_fade_duration, :hint_max_lines, :hint_style, :hint_text, :hover_color, :icon, :ignore_pointers, :ignore_up_down_keys, :input_filter, :key, :keyboard_brightness, :keyboard_type, :label, :label_style, :left, :margin, :max_length, :max_lines, :min_lines, :mouse_cursor, :multiline, :obscuring_character, :offset, :opacity, :password, :prefix, :prefix_icon, :prefix_icon_size_constraints, :prefix_style, :read_only, :right, :rotate, :rtl, :scale, :scroll_padding, :selection, :selection_color, :shift_enter, :show_cursor, :size_change_interval, :size_constraints, :smart_dashes_type, :smart_quotes_type, :strut_style, :suffix, :suffix_icon, :suffix_icon_size_constraints, :suffix_style, :text_align, :text_size, :text_style, :text_vertical_align, :tooltip, :top, :value, :visible, :width, :on_animation_end, :on_blur, :on_change, :on_click, :on_focus, :on_selection_change, :on_size_change, :on_submit, :on_tap_outside].freeze

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
