# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CanvasControl < Ruflet::Control
          TYPE = "canvas".freeze
          WIRE = "Canvas".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :resize_interval, :right, :rotate, :rtl, :scale, :shapes, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_resize, :on_size_change].freeze

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
