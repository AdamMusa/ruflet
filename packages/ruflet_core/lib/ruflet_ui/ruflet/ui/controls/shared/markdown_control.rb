# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class MarkdownControl < Ruflet::Control
          TYPE = "markdown".freeze
          WIRE = "Markdown".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_follow_links, :auto_follow_links_target, :badge, :bottom, :code_style_sheet, :code_theme, :col, :data, :disabled, :expand, :expand_loose, :extension_set, :fit_content, :height, :image_error_content, :key, :latex_scale_factor, :latex_style, :left, :margin, :md_style_sheet, :offset, :opacity, :right, :rotate, :rtl, :scale, :selectable, :shrink_wrap, :size_change_interval, :soft_line_break, :tooltip, :top, :value, :visible, :width, :on_animation_end, :on_selection_change, :on_size_change, :on_tap_link, :on_tap_text].freeze

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
