# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Sizes its `content` to the content's own intrinsic width (Flutter's
        # IntrinsicWidth), e.g. a Column of buttons as wide as the widest one.
        # `step_width`/`step_height` round the size up to a multiple.
        class IntrinsicWidthControl < Ruflet::Control
          TYPE = "intrinsicwidth".freeze
          WIRE = "IntrinsicWidth".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :step_height, :step_width, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            %i[step_width step_height].each do |step|
              value = props[step]
              next if value.nil?
              next if value.is_a?(Numeric) && value >= 0

              raise ArgumentError, "#{step} must be a non-negative number, got #{value.inspect}"
            end

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
          end
        end
      end
    end
  end
end
