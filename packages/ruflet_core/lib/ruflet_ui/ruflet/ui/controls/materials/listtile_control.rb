# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ListTileControl < Ruflet::Control
          TYPE = "listtile".freeze
          WIRE = "ListTile".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :bottom, :col, :content_padding, :data, :dense, :disabled, :enable_feedback, :expand, :expand_loose, :height, :horizontal_spacing, :hover_color, :icon_color, :is_three_line, :key, :leading, :leading_and_trailing_text_style, :left, :margin, :min_height, :min_leading_width, :min_vertical_padding, :mouse_cursor, :offset, :opacity, :right, :rotate, :rtl, :scale, :selected, :selected_color, :selected_tile_color, :shape, :size_change_interval, :splash_color, :style, :subtitle, :subtitle_text_style, :text_color, :title, :title_alignment, :title_text_style, :toggle_inputs, :tooltip, :top, :trailing, :url, :visible, :visual_density, :width, :on_animation_end, :on_click, :on_long_press, :on_size_change].freeze

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
