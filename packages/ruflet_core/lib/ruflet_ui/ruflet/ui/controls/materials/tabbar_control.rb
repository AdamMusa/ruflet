# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class TabBarControl < Ruflet::Control
          TYPE = "tabbar".freeze
          WIRE = "TabBar".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :data, :disabled, :divider_color, :divider_height, :enable_feedback, :expand, :expand_loose, :height, :indicator, :indicator_animation, :indicator_color, :indicator_size, :indicator_thickness, :key, :label_color, :label_padding, :label_text_style, :left, :margin, :mouse_cursor, :offset, :opacity, :overlay_color, :padding, :right, :rotate, :rtl, :scale, :scrollable, :secondary, :size_change_interval, :splash_border_radius, :tab_alignment, :tabs, :tooltip, :top, :unselected_label_color, :unselected_label_text_style, :visible, :width, :on_animation_end, :on_click, :on_hover, :on_size_change].freeze

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
