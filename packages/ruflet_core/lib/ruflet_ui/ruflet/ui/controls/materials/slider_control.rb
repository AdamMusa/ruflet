# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SliderControl < Ruflet::Control
          TYPE = "slider".freeze
          WIRE = "Slider".freeze

          KEYWORDS = [:active_color, :adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bottom, :col, :data, :disabled, :divisions, :expand, :expand_loose, :height, :inactive_color, :interaction, :key, :label, :left, :margin, :max, :min, :mouse_cursor, :offset, :opacity, :overlay_color, :padding, :right, :rotate, :round, :rtl, :scale, :secondary_active_color, :secondary_track_value, :size_change_interval, :thumb_color, :tooltip, :top, :value, :visible, :width, :year_2023, :on_animation_end, :on_blur, :on_change, :on_change_end, :on_change_start, :on_focus, :on_size_change].freeze

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
