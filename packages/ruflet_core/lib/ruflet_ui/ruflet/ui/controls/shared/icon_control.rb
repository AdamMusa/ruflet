# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class IconControl < Ruflet::Control
          TYPE = "icon".freeze
          WIRE = "Icon".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :apply_text_scaling, :aspect_ratio, :badge, :blend_mode, :bottom, :col, :color, :data, :disabled, :expand, :expand_loose, :fill, :grade, :height, :icon, :key, :left, :margin, :offset, :opacity, :optical_size, :right, :rotate, :rtl, :scale, :semantics_label, :shadows, :size, :size_change_interval, :tooltip, :top, :visible, :weight, :width, :on_animation_end, :on_size_change].freeze

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
