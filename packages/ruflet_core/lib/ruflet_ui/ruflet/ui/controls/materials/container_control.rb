# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ContainerControl < Ruflet::Control
          TYPE = "container".freeze
          WIRE = "Container".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :blend_mode, :blur, :border, :border_radius, :bottom, :clip_behavior, :col, :color_filter, :content, :dark_theme, :data, :disabled, :expand, :expand_loose, :foreground_decoration, :gradient, :height, :ignore_interactions, :image, :ink, :ink_color, :key, :left, :margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :shadow, :shape, :size_change_interval, :theme, :theme_mode, :tooltip, :top, :url, :visible, :width, :on_animation_end, :on_click, :on_hover, :on_long_press, :on_size_change, :on_tap_down].freeze

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
