# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ColumnControl < Ruflet::Control
          TYPE = "column".freeze
          WIRE = "Column".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :badge, :bottom, :col, :controls, :data, :disabled, :expand, :expand_loose, :height, :horizontal_alignment, :intrinsic_width, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :run_alignment, :run_spacing, :scale, :scroll, :scroll_interval, :size_change_interval, :spacing, :tight, :tooltip, :top, :visible, :width, :wrap, :on_animation_end, :on_scroll, :on_size_change].freeze

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
