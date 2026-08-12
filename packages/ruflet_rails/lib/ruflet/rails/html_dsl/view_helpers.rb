# frozen_string_literal: true

require "erb"
require "json"

module Ruflet
  module Rails
    module HtmlDsl
      # ERB helpers for authoring HTML DSL screens in Ruby instead of raw
      # tags. Auto-included into ActionView (see Railtie):
      #
      #   <%= column class: "p-6 gap-4 items-center" do %>
      #     <%= text @count, class: "text-5xl font-bold" %>
      #     <%= row class: "gap-3" do %>
      #       <%= button "Up", variant: "filled", icon: "add",
      #                  on_click: counter_increment_path %>
      #     <% end %>
      #   <% end %>
      #
      # Helpers emit the same markup the tag DSL uses, so both styles mix
      # freely in one template. Attribute keys are snake_case and become
      # kebab-case (`on_click:` -> `on-click`); Hash/Array values serialize
      # as JSON; `true` renders a bare attribute and nil/false are dropped.
      module ViewHelpers
        # --- layout -----------------------------------------------------------

        def column(content = nil, **attrs, &block) = ruflet_dsl_tag("column", content, attrs, &block)
        def row(content = nil, **attrs, &block) = ruflet_dsl_tag("row", content, attrs, &block)
        def stack(content = nil, **attrs, &block) = ruflet_dsl_tag("stack", content, attrs, &block)
        def container(content = nil, **attrs, &block) = ruflet_dsl_tag("container", content, attrs, &block)
        def section(content = nil, **attrs, &block) = ruflet_dsl_tag("section", content, attrs, &block)
        def card(content = nil, **attrs, &block) = ruflet_dsl_tag("card", content, attrs, &block)
        def center(content = nil, **attrs, &block) = ruflet_dsl_tag("center", content, attrs, &block)
        def list(content = nil, **attrs, &block) = ruflet_dsl_tag("list", content, attrs, &block)
        def grid(content = nil, **attrs, &block) = ruflet_dsl_tag("grid", content, attrs, &block)
        def spacer(**attrs) = ruflet_dsl_tag("spacer", nil, attrs)
        def divider(**attrs) = ruflet_dsl_tag("divider", nil, attrs)

        # --- content ----------------------------------------------------------

        def text(value = nil, **attrs, &block) = ruflet_dsl_tag("text", value, attrs, &block)
        def markdown(value = nil, **attrs, &block) = ruflet_dsl_tag("markdown", value, attrs, &block)
        def icon(name, **attrs) = ruflet_dsl_tag("icon", nil, attrs.merge(name: name))
        def image(src, **attrs) = ruflet_dsl_tag("img", nil, attrs.merge(src: src))

        def heading(value = nil, level: 1, **attrs, &block)
          ruflet_dsl_tag("h#{level.to_i.clamp(1, 6)}", value, attrs, &block)
        end

        (1..6).each do |level|
          define_method("h#{level}") do |value = nil, **attrs, &block|
            heading(value, level: level, **attrs, &block)
          end
        end

        # --- interactive ------------------------------------------------------

        # button "Up", on_click: "/counter/increment"       (POST + re-render)
        # button "Open", href: "/settings"                  (push a screen)
        # button "Remove", on_click: "delete:/items/3", variant: "outlined"
        # button "Copy", service: "copy", text: "Hello"     (run a native service)
        def button(label = nil, **attrs, &block) = ruflet_dsl_tag("button", label, attrs, &block)

        # link "Settings", "/settings"
        # link "Home", "/", nav: "root"
        def link(label, href, **attrs, &block)
          ruflet_dsl_tag("a", label, attrs.merge(href: href), &block)
        end

        # --- app chrome ---------------------------------------------------------

        # appbar "Inbox", leading_icon: "menu" do
        #   appbar_action "search", "/search"
        # end
        def appbar(title = nil, **attrs, &block)
          ruflet_dsl_tag("appbar", nil, attrs.merge(title: title), &block)
        end

        def appbar_action(icon, href = nil, **attrs)
          ruflet_dsl_tag("action", nil, attrs.merge(icon: icon, href: href))
        end

        # fab icon: "add", href: "/items/new"  (mounts as the screen's FAB)
        def fab(label = nil, **attrs, &block)
          ruflet_dsl_tag("fab", label, attrs, &block)
        end

        # bottom_nav do
        #   nav_item icon: "chat", label: "Chats", href: "/chats", selected: true
        #   nav_item icon: "call", label: "Calls", href: "/calls"
        # end
        def bottom_nav(**attrs, &block) = ruflet_dsl_tag("bottom-nav", nil, attrs, &block)
        def nav_item(**attrs) = ruflet_dsl_tag("nav-item", nil, attrs)

        # --- richer components --------------------------------------------------

        def badge(label = nil, **attrs, &block)
          ruflet_dsl_tag("badge", nil, attrs.merge(label: label), &block)
        end

        def tooltip(message, **attrs, &block)
          ruflet_dsl_tag("tooltip", nil, attrs.merge(message: message), &block)
        end

        def avatar(content = nil, **attrs)
          ruflet_dsl_tag("avatar", content, attrs)
        end

        def chip(label = nil, **attrs, &block)
          ruflet_dsl_tag("chip", label, attrs, &block)
        end

        def progress(**attrs) = ruflet_dsl_tag("progress", nil, attrs)
        def switch(**attrs) = ruflet_dsl_tag("switch", nil, attrs)
        def checkbox(**attrs) = ruflet_dsl_tag("checkbox", nil, attrs)
        def slider(**attrs) = ruflet_dsl_tag("slider", nil, attrs)
        def radio(**attrs) = ruflet_dsl_tag("radio", nil, attrs)

        # list_tile title: "Inbox", subtitle: "12 unread", leading: "mail", href: "/inbox"
        def list_tile(**attrs, &block) = ruflet_dsl_tag("list-tile", nil, attrs, &block)

        # expansion_tile title: "Details" do … end
        def expansion_tile(title = nil, **attrs, &block)
          ruflet_dsl_tag("expansion-tile", nil, attrs.merge(title: title), &block)
        end

        # radio_group "plan", value: "pro" do
        #   radio value: "free", label: "Free"
        #   radio value: "pro", label: "Pro"
        # end
        def radio_group(name = nil, **attrs, &block)
          ruflet_dsl_tag("radio-group", nil, attrs.merge(name: name), &block)
        end

        # segmented_button "view", value: "list",
        #   segments: [{ value: "list", label: "List", icon: "list" }, …]
        def segmented_button(name = nil, segments: [], value: nil, **attrs)
          rendered = Array(segments).map do |seg|
            seg = { value: seg } unless seg.is_a?(Hash)
            ruflet_dsl_tag("segment", seg[:label], { value: seg[:value], icon: seg[:icon] })
          end.join
          ruflet_dsl_tag("segmented-button", rendered, attrs.merge(name: name, value: value), raw: true)
        end

        # tabs do
        #   tab "Overview" do … end
        #   tab "Details", icon: "info" do … end
        # end
        def tabs(**attrs, &block) = ruflet_dsl_tag("tabs", nil, attrs, &block)

        def tab(label = nil, **attrs, &block)
          ruflet_dsl_tag("tab", nil, attrs.merge(label: label), &block)
        end

        # --- forms ----------------------------------------------------------------

        def form(action:, method: "post", **attrs, &block)
          ruflet_dsl_tag("form", nil, attrs.merge(action: action, method: method), &block)
        end

        def input(name = nil, **attrs)
          ruflet_dsl_tag("input", nil, attrs.merge(name: name))
        end

        def textarea(name = nil, value = nil, **attrs)
          ruflet_dsl_tag("textarea", value, attrs.merge(name: name))
        end

        def submit(label = "Submit", **attrs)
          ruflet_dsl_tag("input", nil, attrs.merge(type: "submit", value: label))
        end

        # dropdown "locale", options: [["fr", "Français"], ["en", "English"]],
        #          value: "en", label: "Language"
        def dropdown(name = nil, options: [], value: nil, **attrs)
          rendered = options.map do |option|
            option_value, option_label = option.is_a?(Array) ? option : [option, option]
            selected = !value.nil? && option_value.to_s == value.to_s
            ruflet_dsl_tag("option", option_label, { value: option_value, selected: selected || nil })
          end.join
          ruflet_dsl_tag("select", rendered, attrs.merge(name: name), raw: true)
        end

        # --- services & extensions -----------------------------------------------

        # Non-visual platform services. Drop one on a screen to make it available:
        #   <%= geolocator %>        <%= battery %>        <%= connectivity %>
        SERVICE_HELPERS = %w[
          audio audio_recorder barometer battery clipboard connectivity
          file_picker flashlight geolocator gyroscope accelerometer magnetometer
          haptic_feedback permission_handler screen_brightness secure_storage
          shake_detector share shared_preferences storage_paths url_launcher
          user_accelerometer wakelock semantics_service
        ].freeze

        # Visible extension controls — they render inline like any other control.
        # Use each control's real attributes (a wrong one renders a small inline
        # placeholder instead of crashing the screen):
        #   <%= lottie src: "loader.json" %>   <%= code_editor "puts 1", language: "ruby" %>
        #   <%= video playlist: [{ resource: "clip.mp4" }] %>   <%= map %>
        EXTENSION_HELPERS = %w[
          video lottie code_editor map web_view color_picker camera
          bar_chart line_chart pie_chart scatter_chart candlestick_chart radar_chart
        ].freeze

        # Named extension children used by Map and similar compound controls.
        # These helpers allow Studio expressions such as marker_layer([...]) to
        # be translated directly into nested ERB tags.
        EXTENSION_CHILD_HELPERS = %w[
          tile_layer marker_layer marker circle_layer circle_marker
          polyline_layer polyline_marker polygon_layer polygon_marker
          simple_attribution
        ].freeze

        # Chart data primitives. Nest them inside a chart to supply its data:
        #   <%= bar_chart width: 320, height: 180 do %>
        #     <%= bar_chart_group x: 0 do %>
        #       <%= bar_chart_rod from_y: 0, to_y: 40, color: "#69db7c" %>
        #     <% end %>
        #   <% end %>
        CHART_HELPERS = %w[
          bar_chart_group bar_chart_rod bar_chart_rod_stack_item
          line_chart_data line_chart_data_point pie_chart_section
          candlestick_chart_spot scatter_chart_spot
          radar_dataset radar_dataset_entry radar_chart_title
          chart_axis chart_axis_label
        ].freeze

        (SERVICE_HELPERS + EXTENSION_HELPERS + EXTENSION_CHILD_HELPERS + CHART_HELPERS).each do |name|
          tag = name.tr("_", "-")
          define_method(name) do |content = nil, **attrs, &block|
            ruflet_dsl_tag(tag, content, attrs, &block)
          end
        end

        # Rive takes its animation URL as `src`, like `image` — the auto-generated
        # helper would put the URL in the element body (text content) instead, so
        # the animation never loads. Give it a dedicated helper.
        #   <%= rive "https://cdn.rive.app/animations/vehicles.riv", fit: "contain" %>
        def rive(src = nil, **attrs, &block)
          ruflet_dsl_tag("rive", nil, attrs.merge(src: src), &block)
        end

        # Preserve Ruflet Studio's public API in ERB:
        #   <%= spinkit wave: { color: "#74c0fc", size: 48 } %>
        # The native control receives normalized variant/color/size props.
        def spinkit(**variants)
          allowed = Ruflet::UI::MaterialControlMethods::SPINKIT_VARIANTS
          selected = variants.select { |name, _value| allowed.include?(name.to_sym) }
          raise ArgumentError, "spinkit requires exactly one variant" unless selected.length == 1 && selected.length == variants.length

          variant, options = selected.first
          raise ArgumentError, "spinkit variant options must be a Hash" unless options.is_a?(Hash)

          ruflet_dsl_tag("spinkit", nil, options.merge(variant: variant.to_s))
        end

        # --- anything in the control registry ------------------------------------

        # widget "progress-bar", value: 0.4
        # widget "switch", label: "Dark mode", on_change: "/theme/toggle"
        def widget(tag_name, content = nil, **attrs, &block)
          ruflet_dsl_tag(tag_name.to_s.tr("_", "-"), content, attrs, &block)
        end

        private

        def ruflet_dsl_tag(tag_name, content, attrs, raw: false, &block)
          inner = raw ? content : ruflet_dsl_content(content, &block)
          markup = +"<#{tag_name}"
          attrs.each do |key, value|
            next if value.nil? || value == false

            name = key.to_s.tr("_", "-")
            if value == true
              markup << " #{name}"
            else
              value = JSON.generate(value) if value.is_a?(Hash) || value.is_a?(Array)
              markup << %( #{name}="#{ERB::Util.html_escape(value)}")
            end
          end
          markup << ">"
          markup << inner.to_s
          markup << "</#{tag_name}>"
          ruflet_dsl_safe(markup)
        end

        def ruflet_dsl_content(content, &block)
          if block
            respond_to?(:capture) ? capture(&block) : block.call
          elsif content.respond_to?(:html_safe?) && content.html_safe?
            content
          elsif content.nil?
            nil
          else
            ERB::Util.html_escape(content.to_s)
          end
        end

        def ruflet_dsl_safe(string)
          string.respond_to?(:html_safe) ? string.html_safe : string
        end
      end
    end
  end
end
