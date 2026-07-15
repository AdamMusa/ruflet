# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class MenuItemButtonControl < Ruflet::Control
          TYPE = "menuitembutton".freeze
          WIRE = "MenuItemButton".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bottom, :clip_behavior, :close_on_click, :col, :content, :data, :disabled, :expand, :expand_loose, :focus_on_hover, :height, :key, :leading, :left, :margin, :offset, :opacity, :overflow_axis, :right, :rotate, :rtl, :scale, :semantic_label, :size_change_interval, :style, :tooltip, :top, :trailing, :visible, :width, :on_animation_end, :on_blur, :on_click, :on_focus, :on_hover, :on_size_change].freeze

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
