# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Fades its `content` from opacity `begin` (default 0) to `end`
        # (default 1) over `duration` milliseconds (Flutter's FadeTransition
        # driven by an AnimationController). `repeat: true` loops it,
        # `reverse: true` makes the loop ping-pong (a breathing loader),
        # `animating: false` pauses it and `delay` waits before the first run.
        # `on_animation_end` fires when a run that does not repeat finishes.
        class FadeTransitionControl < Ruflet::Control
          TYPE = "fadetransition".freeze
          WIRE = "FadeTransition".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animating, :aspect_ratio, :badge, :begin, :bottom, :col, :content, :curve, :data, :delay, :disabled, :duration, :end, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :repeat, :reverse, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.timing_props(props, KEYWORDS)
            props[:begin] = Controls::TransitionSupport.number(:begin, props.fetch(:begin, 0.0), min: 0, max: 1)
            props[:end] = Controls::TransitionSupport.number(:end, props.fetch(:end, 1.0), min: 0, max: 1)

            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
