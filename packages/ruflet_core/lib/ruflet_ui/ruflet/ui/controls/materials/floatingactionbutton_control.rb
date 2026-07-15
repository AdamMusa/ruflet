# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class FloatingActionButtonControl < Ruflet::Control
          TYPE = "floatingactionbutton".freeze
          WIRE = "FloatingActionButton".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :autofocus, :badge, :bgcolor, :bottom, :clip_behavior, :col, :content, :data, :disabled, :disabled_elevation, :elevation, :enable_feedback, :expand, :expand_loose, :focus_color, :focus_elevation, :foreground_color, :height, :highlight_elevation, :hover_color, :hover_elevation, :icon, :key, :left, :margin, :mini, :mouse_cursor, :offset, :opacity, :right, :rotate, :rtl, :scale, :shape, :size_change_interval, :splash_color, :tooltip, :top, :url, :visible, :width, :on_animation_end, :on_click, :on_size_change].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          private

          def blank_content?(value)
            value.nil? || (value.respond_to?(:empty?) && value.empty?)
          end
        end
      end
    end
  end
end
