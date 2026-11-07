# frozen_string_literal: true

require_relative "scrollable_methods"

module Ruflet
  module UI
    module Controls
      module RufletComponents
        # Flutter's NestedScrollView: header slivers (typically a pinned
        # sliver_app_bar with a tab_bar as its `bottom`) that collapse as the
        # `body` scrolls. Header slivers are given as `header_slivers:` or as
        # block children (`controls`), like custom_scroll_view's slivers.
        #
        #   tabs(length: 2) do
        #     nested_scroll_view(body: tab_bar_view([list_view(inbox), list_view(sent)])) do
        #       sliver_app_bar(title: text("Mail"), pinned: true,
        #                      bottom: tab_bar(tabs: [tab(label: "Inbox"), tab(label: "Sent")]))
        #     end
        #   end
        #
        # `body` is one control. Make the scrolling list the body itself, or
        # each page of a tab_bar_view body: a list_view, grid_view,
        # custom_scroll_view, or column/row with `scroll:`. Those drive the
        # header (it collapses before they scroll) and start below a pinned
        # header, then scroll under it. Any other body is placed below the
        # pinned header; a list nested deeper inside it scrolls on its own
        # without collapsing the header.
        #
        # `scroll_to`, `scroll`, `auto_scroll` and `on_scroll` act on the outer
        # (header) scroll: `scroll_to(offset: 0)` expands the header and
        # returns the body lists to their top, `scroll_to(offset: -1)`
        # collapses it. The body lists keep their own `scroll_to`/`on_scroll`.
        class NestedScrollViewControl < Ruflet::Control
          include ScrollableMethods

          TYPE = "nestedscrollview".freeze
          WIRE = "NestedScrollView".freeze

          KEYWORDS = [:align, :animate_align, :animate_margin, :animate_offset, :animate_opacity, :animate_position, :animate_rotation, :animate_scale, :animate_size, :aspect_ratio, :auto_scroll, :badge, :body, :bottom, :clip_behavior, :col, :controls, :data, :disabled, :expand, :expand_loose, :float_header_slivers, :header_slivers, :height, :horizontal, :key, :left, :margin, :offset, :opacity, :reverse, :right, :rotate, :rtl, :scale, :scroll, :scroll_interval, :size_change_interval, :tooltip, :top, :visible, :width, :on_animation_end, :on_scroll, :on_size_change].freeze

          def initialize(id: nil, **props)
            unknown = props.keys.reject { |key| KEYWORDS.include?(key) }
            raise ArgumentError, "unknown keywords: #{unknown.join(', ')}" unless unknown.empty?

            body = props[:body]
            unless body.is_a?(Ruflet::Control)
              raise ArgumentError, "nested_scroll_view body must be a control, got #{body.inspect}"
            end

            props = props.reject { |_key, value| value.nil? }
            props[:float_header_slivers] = false unless props.key?(:float_header_slivers)
            props[:horizontal] = false unless props.key?(:horizontal)
            props[:reverse] = false unless props.key?(:reverse)
            super(type: TYPE, id: id, **props)
          end
        end
      end
    end
  end
end
