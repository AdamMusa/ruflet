# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Turns its `content` from `begin` to `end` turns (defaults 0 and 1:
        # one full turn) around `alignment` (default the centre) over
        # `duration` milliseconds (Flutter's RotationTransition). With
        # `repeat: true` it spins until `animating: false` or removal.
        # Timing keywords as for fade_transition.
        class RotationTransitionControl < Ruflet::Control
          TYPE = "rotationtransition".freeze
          WIRE = "RotationTransition".freeze

          KEYWORDS = [:align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animating, :aspect_ratio, :badge, :begin, :bottom, :col, :content, :curve, :data, :delay, :disabled, :duration, :end, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :repeat, :reverse, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.timing_props(props, KEYWORDS)
            props[:begin] = Controls::TransitionSupport.number(:begin, props.fetch(:begin, 0.0))
            props[:end] = Controls::TransitionSupport.number(:end, props.fetch(:end, 1.0))
            props[:alignment] = Controls::TransitionSupport.alignment(:alignment, props[:alignment]) if props.key?(:alignment)

            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
