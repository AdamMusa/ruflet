# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class WindowControl < Ruflet::Control
          TYPE = "window".freeze
          WIRE = "Window".freeze

          KEYWORDS = [:alignment, :always_on_bottom, :always_on_top, :aspect_ratio, :badge_label, :bgcolor, :brightness, :data, :focused, :frameless, :full_screen, :height, :icon, :ignore_mouse_events, :key, :left, :max_height, :max_width, :maximizable, :maximized, :min_height, :min_width, :minimizable, :minimized, :movable, :opacity, :prevent_close, :progress_bar, :resizable, :shadow, :skip_task_bar, :title_bar_buttons_hidden, :title_bar_hidden, :top, :visible, :width, :on_event].freeze

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
