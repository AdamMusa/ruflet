# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ShimmerControl < Ruflet::Control
          TYPE = "shimmer".freeze
          WIRE = "Shimmer".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :base_color, :bottom, :col, :content, :data, :direction, :disabled, :expand, :expand_loose, :gradient, :height, :highlight_color, :key, :left, :loop, :margin, :offset, :opacity, :period, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

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
