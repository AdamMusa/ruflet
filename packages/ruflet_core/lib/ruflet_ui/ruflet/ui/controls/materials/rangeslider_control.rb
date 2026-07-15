# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RangeSliderControl < Ruflet::Control
          TYPE = "rangeslider".freeze
          WIRE = "RangeSlider".freeze

          KEYWORDS = [:active_color, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :data, :disabled, :divisions, :end_value, :expand, :expand_loose, :height, :inactive_color, :key, :label, :left, :margin, :max, :min, :mouse_cursor, :offset, :opacity, :overlay_color, :right, :rotate, :round, :rtl, :scale, :size_change_interval, :start_value, :tooltip, :top, :visible, :width, :on_animation_end, :on_change, :on_change_end, :on_change_start, :on_size_change].freeze

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
