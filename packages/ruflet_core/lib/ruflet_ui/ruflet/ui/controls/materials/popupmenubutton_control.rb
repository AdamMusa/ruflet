# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PopupMenuButtonControl < Ruflet::Control
          TYPE = "popupmenubutton".freeze
          WIRE = "PopupMenuButton".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :clip_behavior, :col, :content, :data, :disabled, :elevation, :enable_feedback, :expand, :expand_loose, :height, :icon, :icon_color, :icon_size, :items, :key, :left, :margin, :menu_padding, :menu_position, :offset, :opacity, :padding, :popup_animation_style, :right, :rotate, :rtl, :scale, :shadow_color, :shape, :size_change_interval, :size_constraints, :splash_radius, :style, :tooltip, :top, :visible, :width, :on_animation_end, :on_cancel, :on_open, :on_select, :on_size_change].freeze

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
