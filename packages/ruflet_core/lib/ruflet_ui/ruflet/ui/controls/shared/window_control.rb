# frozen_string_literal: true

module Ruflet
  module UI
    module Controls
      module RufletComponents
        class WindowControl < Ruflet::Control
          TYPE = "window".freeze
          WIRE = "Window".freeze
          RESIZE_EDGES = {
            "top" => "top",
            "left" => "left",
            "right" => "right",
            "bottom" => "bottom",
            "top_left" => "topLeft",
            "bottom_left" => "bottomLeft",
            "top_right" => "topRight",
            "bottom_right" => "bottomRight"
          }.freeze

          KEYWORDS = [:alignment, :always_on_bottom, :always_on_top, :aspect_ratio, :badge_label, :bgcolor, :brightness, :data, :focused, :frameless, :full_screen, :height, :icon, :ignore_mouse_events, :key, :left, :max_height, :max_width, :maximizable, :maximized, :min_height, :min_width, :minimizable, :minimized, :movable, :opacity, :prevent_close, :progress_bar, :resizable, :shadow, :skip_task_bar, :title_bar_buttons_hidden, :title_bar_hidden, :top, :visible, :width, :on_event].freeze

          def initialize(id: nil, **props)
            compact = {}
            props.each do |key, value|
              raise ArgumentError, "unknown keyword: :#{key}" unless KEYWORDS.include?(key)
              compact[key] = value unless value.nil?
            end
            super(type: TYPE, id: id, **compact)
          end

          %w[
            wait_until_ready_to_show
            destroy
            center
            close
            to_front
            start_dragging
          ].each do |method_name|
            define_method(method_name) do |timeout: 10, on_result: nil|
              invoke_window(method_name, timeout: timeout, on_result: on_result)
            end
          end

          def start_resizing(edge, timeout: 10, on_result: nil)
            edge_value = RESIZE_EDGES.fetch(edge.to_s, edge.to_s)
            invoke_window(
              "start_resizing",
              args: { "edge" => edge_value },
              timeout: timeout,
              on_result: on_result
            )
          end

          private

          def invoke_window(method_name, args: nil, timeout:, on_result:)
            runtime_page&.invoke(
              self,
              method_name,
              args: args,
              timeout: timeout,
              on_result: on_result
            )
          end
        end
      end
    end
  end
end
