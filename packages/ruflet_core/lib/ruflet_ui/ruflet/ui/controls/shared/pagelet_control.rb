# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class PageletControl < Ruflet::Control
          TYPE = "pagelet".freeze
          WIRE = "Pagelet".freeze

          KEYWORDS = [:adaptive, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :appbar, :aspect_ratio, :badge, :bgcolor, :bottom, :bottom_appbar, :bottom_sheet, :col, :content, :data, :disabled, :drawer, :end_drawer, :expand, :expand_loose, :floating_action_button, :floating_action_button_location, :height, :key, :left, :margin, :navigation_bar, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

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
