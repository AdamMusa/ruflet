# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Clips its `content` to a rounded rectangle with continuous
        # ("squircle") corners, the iOS app-icon shape (Flutter's
        # ClipRSuperellipse). A container's border_radius rounds with
        # circular arcs; this is the smooth iOS curve. `border_radius` is one
        # radius for every corner or { top_left:, top_right:, bottom_left:,
        # bottom_right: }; `clip_behavior` as for clip_oval.
        class ClipRSuperellipseControl < Ruflet::Control
          TYPE = "cliprsuperellipse".freeze
          WIRE = "ClipRSuperellipse".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :border_radius, :bottom, :clip_behavior, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.known_props(props, KEYWORDS)
            props[:border_radius] = Controls::TransitionSupport.border_radius(props[:border_radius]) if props.key?(:border_radius)
            if props.key?(:clip_behavior)
              props[:clip_behavior] = Controls::TransitionSupport.clip_behavior(props[:clip_behavior])
            end

            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
