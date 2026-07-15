# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class NavigationBarControl < Ruflet::Control
          TYPE = "navigationbar".freeze
          WIRE = "NavigationBar".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animation_duration, :aspect_ratio, :badge, :bgcolor, :border, :bottom, :col, :data, :destinations, :disabled, :elevation, :expand, :expand_loose, :height, :indicator_color, :indicator_shape, :key, :label_behavior, :label_padding, :left, :margin, :offset, :opacity, :overlay_color, :right, :rotate, :rtl, :scale, :selected_index, :shadow_color, :size_change_interval, :surface_tint_color, :tooltip, :top, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
