# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class ReorderableListViewControl < Ruflet::Control
          TYPE = "reorderablelistview".freeze
          WIRE = "ReorderableListView".freeze

          KEYWORDS = [:adaptive, :align, :anchor, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :auto_scroller_velocity_scalar, :badge, :bottom, :build_controls_on_demand, :cache_extent, :clip_behavior, :col, :controls, :data, :disabled, :divider_thickness, :expand, :expand_loose, :first_item_prototype, :footer, :header, :height, :horizontal, :item_extent, :key, :left, :margin, :mouse_cursor, :offset, :opacity, :padding, :prototype_item, :reverse, :right, :rotate, :rtl, :scale, :scroll, :scroll_interval, :semantic_child_count, :show_default_drag_handles, :size_change_interval, :spacing, :tooltip, :top, :visible, :width, :on_animation_end, :on_reorder, :on_reorder_end, :on_reorder_start, :on_scroll, :on_size_change].freeze

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
