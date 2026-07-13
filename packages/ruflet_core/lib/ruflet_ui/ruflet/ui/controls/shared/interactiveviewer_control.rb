# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class InteractiveViewerControl < Ruflet::Control
          TYPE = "interactiveviewer".freeze
          WIRE = "InteractiveViewer".freeze

          KEYWORDS = [:align, :alignment, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :badge, :bottom, :boundary_margin, :clip_behavior, :col, :constrained, :content, :data, :disabled, :expand, :expand_loose, :height, :interaction_end_friction_coefficient, :interaction_update_interval, :key, :left, :margin, :max_scale, :min_scale, :offset, :opacity, :pan_enabled, :right, :rotate, :rtl, :scale, :scale_enabled, :scale_factor, :size_change_interval, :tooltip, :top, :trackpad_scroll_causes_scale, :visible, :width, :on_animation_end, :on_interaction_end, :on_interaction_start, :on_interaction_update, :on_size_change].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          def pan(dx, dy: 0, dz: 0, timeout: 10, on_result: nil)
            runtime_page&.invoke(
              self,
              "pan",
              args: { "dx" => dx, "dy" => dy, "dz" => dz },
              timeout: timeout,
              on_result: on_result
            )
          end

          def reset(animation_duration: nil, timeout: 10, on_result: nil)
            args = {}
            args["animation_duration"] = stringify_hash_keys(animation_duration) unless animation_duration.nil?
            runtime_page&.invoke(self, "reset", args: args.empty? ? nil : args, timeout: timeout, on_result: on_result)
          end

          def restore_state(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "restore_state", timeout: timeout, on_result: on_result)
          end

          def save_state(timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "save_state", timeout: timeout, on_result: on_result)
          end

          def zoom(factor, timeout: 10, on_result: nil)
            runtime_page&.invoke(self, "zoom", args: { "factor" => factor }, timeout: timeout, on_result: on_result)
          end

          private

          def stringify_hash_keys(value)
            return value.map { |item| stringify_hash_keys(item) } if value.is_a?(Array)
            return value.each_with_object({}) { |(key, child), result| result[key.to_s] = stringify_hash_keys(child) } if value.is_a?(Hash)

            value
          end
        end
      end
    end
  end
end
