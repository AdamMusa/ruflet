# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Sizes its `content` to the content's own intrinsic height (Flutter's
        # IntrinsicHeight): the classic use is a Row whose children stretch to
        # the tallest one, e.g. two cards of equal height with a divider.
        class IntrinsicHeightControl < Ruflet::Control
          TYPE = "intrinsicheight".freeze
          WIRE = "IntrinsicHeight".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
          end
        end
      end
    end
  end
end
