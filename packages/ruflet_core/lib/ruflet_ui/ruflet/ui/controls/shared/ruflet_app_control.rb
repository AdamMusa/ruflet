# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class RufletAppControl < Ruflet::Control
          TYPE = "ruflet_app".freeze
          # Ruflet owns its native renderer and protocol, so the public control
          # keeps the Ruflet name all the way onto the wire.
          WIRE = "RufletApp".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :app_error_message, :app_startup_screen_message, :args, :aspect_ratio, :badge, :bottom, :col, :data, :disabled, :expand, :expand_loose, :force_pyodide, :height, :key, :left, :margin, :offset, :opacity, :reconnect_interval_ms, :reconnect_timeout_ms, :right, :rotate, :rtl, :scale, :show_app_startup_screen, :size_change_interval, :tooltip, :top, :url, :visible, :width, :on_animation_end, :on_error, :on_size_change].freeze

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
