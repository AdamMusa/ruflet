# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SegmentedButtonControl < Ruflet::Control
          TYPE = "segmentedbutton".freeze
          WIRE = "SegmentedButton".freeze

          KEYWORDS = [:align, :allow_empty_selection, :allow_multiple_selection, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :data, :direction, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :segments, :selected, :selected_icon, :show_selected_icon, :size_change_interval, :style, :tooltip, :top, :visible, :width, :on_animation_end, :on_change, :on_size_change].freeze

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
