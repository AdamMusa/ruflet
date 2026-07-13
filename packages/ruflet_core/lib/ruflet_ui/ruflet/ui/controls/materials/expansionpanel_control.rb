# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ExpansionPanelControl < Ruflet::Control
          TYPE = "expansionpanel".freeze
          WIRE = "ExpansionPanel".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bgcolor, :bottom, :can_tap_header, :col, :content, :data, :disabled, :expand, :expand_loose, :expanded, :header, :height, :highlight_color, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :splash_color, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

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
