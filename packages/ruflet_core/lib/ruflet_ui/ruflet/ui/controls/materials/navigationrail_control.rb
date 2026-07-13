# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class NavigationRailControl < Ruflet::Control
          TYPE = "navigationrail".freeze
          WIRE = "NavigationRail".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :data, :destinations, :disabled, :elevation, :expand, :expand_loose, :extended, :group_alignment, :height, :indicator_color, :indicator_shape, :key, :label_type, :leading, :left, :margin, :min_extended_width, :min_width, :offset, :opacity, :right, :rotate, :rtl, :scale, :selected_index, :selected_label_text_style, :size_change_interval, :tooltip, :top, :trailing, :unselected_label_text_style, :use_indicator, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
