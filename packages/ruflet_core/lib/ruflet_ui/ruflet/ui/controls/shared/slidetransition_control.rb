# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Moves its `content` from offset `begin` to `end`, in fractions of
        # the content's own size (Flutter's SlideTransition): the defaults
        # `begin: { x: 0, y: 1 }`, `end: { x: 0, y: 0 }` slide it up into
        # place by its height. Timing keywords as for fade_transition.
        class SlideTransitionControl < Ruflet::Control
          TYPE = "slidetransition".freeze
          WIRE = "SlideTransition".freeze

          DEFAULT_BEGIN = { "x" => 0.0, "y" => 1.0 }.freeze
          DEFAULT_END = { "x" => 0.0, "y" => 0.0 }.freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animating, :aspect_ratio, :badge, :begin, :bottom, :col, :content, :curve, :data, :delay, :disabled, :duration, :end, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :repeat, :reverse, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.timing_props(props, KEYWORDS)
            props[:begin] = Controls::TransitionSupport.offset(:begin, props.fetch(:begin, DEFAULT_BEGIN))
            props[:end] = Controls::TransitionSupport.offset(:end, props.fetch(:end, DEFAULT_END))

            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
