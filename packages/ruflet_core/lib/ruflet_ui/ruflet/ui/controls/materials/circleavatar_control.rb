# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CircleAvatarControl < Ruflet::Control
          TYPE = "circleavatar".freeze
          WIRE = "CircleAvatar".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :background_image_src, :badge, :bgcolor, :bottom, :col, :color, :content, :data, :disabled, :expand, :expand_loose, :foreground_image_src, :height, :key, :left, :margin, :max_radius, :min_radius, :offset, :opacity, :radius, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_image_error, :on_size_change].freeze

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
