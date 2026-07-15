# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class IconButtonControl < Ruflet::Control
          TYPE = "iconbutton".freeze
          WIRE = "IconButton".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :bottom, :col, :data, :disabled, :disabled_color, :enable_feedback, :expand, :expand_loose, :focus_color, :height, :highlight_color, :hover_color, :icon, :icon_color, :icon_size, :key, :left, :margin, :mouse_cursor, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :selected, :selected_icon, :selected_icon_color, :size_change_interval, :size_constraints, :splash_color, :splash_radius, :style, :tooltip, :top, :url, :visible, :visual_density, :width, :on_animation_end, :on_blur, :on_click, :on_focus, :on_hover, :on_long_press, :on_size_change].freeze

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
