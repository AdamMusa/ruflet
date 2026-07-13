# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ProgressRingControl < Ruflet::Control
          TYPE = "progressring".freeze
          WIRE = "ProgressRing".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :col, :color, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :semantics_label, :semantics_value, :size_change_interval, :size_constraints, :stroke_align, :stroke_cap, :stroke_width, :tooltip, :top, :track_gap, :value, :visible, :width, :year_2023, :on_animation_end, :on_size_change].freeze

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
