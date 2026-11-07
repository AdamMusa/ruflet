# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Makes its `content` invisible to pointer events while `ignoring` is
        # true (Flutter's IgnorePointer): taps pass through to whatever lies
        # behind it, e.g. a decorative overlay in a Stack.
        class IgnorePointerControl < Ruflet::Control
          TYPE = "ignorepointer".freeze
          WIRE = "IgnorePointer".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :ignoring, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            props[:ignoring] = true if props[:ignoring].nil?

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
          end
        end
      end
    end
  end
end
