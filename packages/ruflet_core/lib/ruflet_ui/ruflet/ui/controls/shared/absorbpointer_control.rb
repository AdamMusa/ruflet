# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Swallows pointer events aimed at its `content` while `absorbing` is
        # true (Flutter's AbsorbPointer): unlike IgnorePointer, nothing behind
        # it receives them either, e.g. a form locked while it saves.
        class AbsorbPointerControl < Ruflet::Control
          TYPE = "absorbpointer".freeze
          WIRE = "AbsorbPointer".freeze

          KEYWORDS = [:absorbing, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :content, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            props[:absorbing] = true if props[:absorbing].nil?

            super(type: TYPE, id: id, **props.reject { |_key, value| value.nil? })
          end
        end
      end
    end
  end
end
