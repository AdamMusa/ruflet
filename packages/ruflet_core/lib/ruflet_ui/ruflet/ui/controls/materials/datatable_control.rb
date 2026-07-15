# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class DataTableControl < Ruflet::Control
          TYPE = "datatable".freeze
          WIRE = "DataTable".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :border, :border_radius, :bottom, :checkbox_horizontal_margin, :clip_behavior, :col, :column_spacing, :columns, :data, :data_row_color, :data_row_max_height, :data_row_min_height, :data_text_style, :disabled, :divider_thickness, :expand, :expand_loose, :gradient, :heading_row_color, :heading_row_height, :heading_text_style, :height, :horizontal_lines, :horizontal_margin, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rows, :rtl, :scale, :show_bottom_border, :show_checkbox_column, :size_change_interval, :sort_ascending, :sort_column_index, :tooltip, :top, :vertical_lines, :visible, :width, :on_animation_end, :on_select_all, :on_size_change].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          private

          def visible_controls(value)
            Array(value).select { |control| !control.respond_to?(:props) || control.props["visible"] != false }
          end
        end
      end
    end
  end
end
