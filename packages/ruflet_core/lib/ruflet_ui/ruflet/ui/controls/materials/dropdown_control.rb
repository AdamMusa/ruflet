# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DropdownControl < Ruflet::Control
          TYPE = "dropdown".freeze
          WIRE = "Dropdown".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :border, :border_color, :border_radius, :border_width, :bottom, :capitalization, :col, :color, :content_padding, :data, :dense, :disabled, :editable, :elevation, :enable_filter, :enable_search, :error_style, :error_text, :expand, :expand_loose, :expanded_insets, :fill_color, :filled, :focused_border_color, :focused_border_width, :height, :helper_style, :helper_text, :hint_style, :hint_text, :hover_color, :input_filter, :key, :label, :label_style, :leading_icon, :left, :margin, :menu_height, :menu_style, :menu_width, :offset, :opacity, :options, :right, :rotate, :rtl, :scale, :selected_suffix, :selected_trailing_icon, :size_change_interval, :text, :text_align, :text_size, :text_style, :tooltip, :top, :trailing_icon, :value, :visible, :width, :on_animation_end, :on_blur, :on_focus, :on_select, :on_size_change, :on_text_change].freeze

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
