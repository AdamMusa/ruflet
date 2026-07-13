# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ButtonControl < Ruflet::Control
          TYPE = "button".freeze
          WIRE = "Button".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :bottom, :clip_behavior, :col, :color, :content, :data, :disabled, :elevation, :expand, :expand_loose, :height, :icon, :icon_color, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :style, :tooltip, :top, :url, :visible, :width, :on_animation_end, :on_blur, :on_click, :on_focus, :on_hover, :on_long_press, :on_size_change].freeze

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
