# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class BottomAppBarControl < Ruflet::Control
          TYPE = "bottomappbar".freeze
          WIRE = "BottomAppBar".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :border_radius, :bottom, :clip_behavior, :col, :content, :data, :disabled, :elevation, :expand, :expand_loose, :height, :key, :left, :margin, :notch_margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :shadow_color, :shape, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

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
