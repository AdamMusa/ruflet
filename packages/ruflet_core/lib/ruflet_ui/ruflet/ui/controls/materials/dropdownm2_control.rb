# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class Dropdown2Control < Ruflet::Control
          TYPE = "dropdownm2".freeze
          WIRE = "DropdownM2".freeze

          KEYWORDS = [:align, :align_label_with_hint, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :border, :border_color, :border_radius, :border_width, :bottom, :col, :collapsed, :color, :content_padding, :counter, :counter_style, :data, :dense, :disabled, :disabled_hint_content, :elevation, :enable_feedback, :error, :error_max_lines, :error_style, :expand, :expand_loose, :fill_color, :filled, :fit_parent_size, :focus_color, :focused_bgcolor, :focused_border_color, :focused_border_width, :focused_color, :height, :helper, :helper_max_lines, :helper_style, :hint_content, :hint_fade_duration, :hint_max_lines, :hint_style, :hint_text, :hover_color, :icon, :item_height, :key, :label, :label_style, :left, :margin, :max_menu_height, :offset, :opacity, :options, :options_fill_horizontally, :padding, :prefix, :prefix_icon, :prefix_icon_size_constraints, :prefix_style, :right, :rotate, :rtl, :scale, :select_icon, :select_icon_disabled_color, :select_icon_enabled_color, :select_icon_size, :size_change_interval, :size_constraints, :suffix, :suffix_icon, :suffix_icon_size_constraints, :suffix_style, :text_size, :text_style, :text_vertical_align, :tooltip, :top, :value, :visible, :width, :on_animation_end, :on_blur, :on_change, :on_click, :on_focus, :on_size_change].freeze

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
