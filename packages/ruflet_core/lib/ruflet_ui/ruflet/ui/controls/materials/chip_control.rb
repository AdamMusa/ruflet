# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ChipControl < Ruflet::Control
          TYPE = "chip".freeze
          WIRE = "Chip".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :border_side, :bottom, :check_color, :clip_behavior, :col, :color, :data, :delete_drawer_animation_style, :delete_icon, :delete_icon_color, :delete_icon_size_constraints, :delete_icon_tooltip, :disabled, :disabled_color, :elevation, :elevation_on_click, :enable_animation_style, :expand, :expand_loose, :height, :key, :label, :label_padding, :label_text_style, :leading, :leading_drawer_animation_style, :leading_size_constraints, :left, :margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :select_animation_style, :selected, :selected_color, :selected_shadow_color, :shadow_color, :shape, :show_checkmark, :size_change_interval, :tooltip, :top, :visible, :visual_density, :width, :on_animation_end, :on_blur, :on_click, :on_delete, :on_focus, :on_select, :on_size_change].freeze

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
