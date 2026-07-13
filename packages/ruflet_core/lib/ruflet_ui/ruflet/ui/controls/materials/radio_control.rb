# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RadioControl < Ruflet::Control
          TYPE = "radio".freeze
          WIRE = "Radio".freeze

          KEYWORDS = [:active_color, :adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bottom, :col, :data, :disabled, :expand, :expand_loose, :fill_color, :focus_color, :height, :hover_color, :key, :label, :label_position, :label_style, :left, :margin, :mouse_cursor, :offset, :opacity, :overlay_color, :right, :rotate, :rtl, :scale, :size_change_interval, :splash_radius, :toggleable, :tooltip, :top, :value, :visible, :visual_density, :width, :on_animation_end, :on_blur, :on_focus, :on_size_change].freeze

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
