# frozen_string_literal: true

require_relative "transition_support"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Clips its `content` to the oval that fills the content's box (a
        # circle for a square): round avatars from any image or control
        # (Flutter's ClipOval). `clip_behavior` is "anti_alias" (default),
        # "hard_edge", "anti_alias_with_save_layer" or "none".
        class ClipOvalControl < Ruflet::Control
          TYPE = "clipoval".freeze
          WIRE = "ClipOval".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :clip_behavior, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            props = Controls::TransitionSupport.known_props(props, KEYWORDS)
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
