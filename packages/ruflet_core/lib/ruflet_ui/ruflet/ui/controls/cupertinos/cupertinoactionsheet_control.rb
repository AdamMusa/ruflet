# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class CupertinoActionSheetControl < Ruflet::Control
          TYPE = "cupertinoactionsheet".freeze
          WIRE = "CupertinoActionSheet".freeze

          KEYWORDS = [:actions, :align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :cancel, :col, :data, :disabled, :expand, :expand_loose, :height, :key, :left, :margin, :message, :offset, :opacity, :right, :rotate, :rtl, :scale, :size_change_interval, :title, :tooltip, :top, :visible, :width, :on_animation_end, :on_size_change].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          private

          def hidden_or_nil?(value) = value.nil? || hidden_control?(value)

          def hidden_control?(value)
            value.respond_to?(:props) && value.props["visible"] == false
          end
        end
      end
    end
  end
end
