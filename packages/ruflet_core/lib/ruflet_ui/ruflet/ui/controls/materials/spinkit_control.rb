# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class SpinkitControl < Ruflet::Control
          TYPE = "spinkit".freeze
          WIRE = "RufletSpinKit".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :col, :color, :data, :disabled, :duration, :expand, :expand_loose, :height, :key, :left, :margin, :offset, :opacity, :padding, :right, :rotate, :rtl, :scale, :size, :size_change_interval, :tooltip, :top, :variant, :visible, :width].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end
        end
      end
    end
  end
end
