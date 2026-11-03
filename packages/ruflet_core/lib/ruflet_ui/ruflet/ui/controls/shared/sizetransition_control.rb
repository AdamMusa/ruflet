# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Grows its `content` along `axis` ("vertical", the default, or
        # "horizontal") from size factor `begin` to `end` (defaults 0 and 1:
        # it unfolds), clipping what does not fit yet (Flutter's
        # SizeTransition). `axis_alignment` (-1..1, default 0) is where along
        # the axis it grows from. Timing keywords as for fade_transition.
        class SizeTransitionControl < Ruflet::Control
          TYPE = "sizetransition".freeze
          WIRE = "SizeTransition".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :animating, :aspect_ratio, :axis, :axis_alignment, :badge, :begin, :bottom, :col, :content, :curve, :data, :delay, :disabled, :duration, :end, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :repeat, :reverse, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.timing_props(props, KEYWORDS)
            props[:begin] = Controls::TransitionSupport.number(:begin, props.fetch(:begin, 0.0), min: 0)
            props[:end] = Controls::TransitionSupport.number(:end, props.fetch(:end, 1.0), min: 0)
            props[:axis] = Controls::TransitionSupport.axis(props[:axis]) if props.key?(:axis)
            if props.key?(:axis_alignment)
              props[:axis_alignment] = Controls::TransitionSupport.number(:axis_alignment, props[:axis_alignment])
            end

            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
