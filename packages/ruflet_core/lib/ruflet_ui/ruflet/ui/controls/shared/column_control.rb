# frozen_string_literal: true

require_relative "scrollable_methods"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ColumnControl < Ruflet::Control
          include ScrollableMethods

          TYPE = "column".freeze
          WIRE = "Column".freeze

          KEYWORDS = [:adaptive, :align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :badge, :bottom, :col, :controls, :data, :disabled, :end_reached_threshold, :expand, :expand_loose, :height, :horizontal_alignment, :intrinsic_width, :key, :keyboard_dismiss_behavior, :left, :margin, :offset, :opacity, :refresh_bgcolor, :refresh_color, :refresh_displacement, :refresh_timeout, :refresh_trigger_distance, :right, :rotate, :rtl, :run_alignment, :run_spacing, :scale, :scroll, :scroll_interval, :size_change_interval, :spacing, :tight, :tooltip, :top, :visible, :width, :wrap, :on_animation_end, :on_end_reached, :on_refresh, :on_scroll, :on_size_change].freeze

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
