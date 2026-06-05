# frozen_string_literal: true

require "ruflet_core"

module Ruflet
  module Rails
    module_function

    # Returns the global configuration object.
    def config
      @config ||= Configuration.new
    end

    # Yields the configuration object for block-style setup.
    #
    #   Ruflet::Rails.configure do |c|
    #     c.app_file = Rails.root.join("app/views/ruflet/main.rb")
    #     c.ws_path  = "/ws"
    #   end
    def configure
      yield config
    end

    def view_classes
      @view_classes ||= []
    end

    def register_view(view_class)
      view_classes << view_class unless view_classes.include?(view_class)
      view_class
    end

    def render(page, routes: nil, default: nil)
      ViewRouter.new(page, routes: routes, default: default).start
    end

    def load_views(root)
      return [] if root.to_s.empty?

      files = Dir[File.join(root.to_s, "components", "**", "*.rb")].sort
      files += Dir[File.join(root.to_s, "**", "*_view.rb")].sort

      files.each do |file|
        Kernel.load(file)
      end
    end

    def sessions
      @sessions ||= SessionRegistry.new
    end

    def broadcast(&block)
      sessions.broadcast(&block)
    end

    # Mount inside Rails routes; route "at:" controls URL path.
    def endpoint(&block)
      Protocol::Runner.new(&block).build_endpoint
    end

    # Load a Ruflet app file (MyApp.new.run) and mount it in Rails routes.
    def app(file_path)
      Protocol::Runner.new.build_app_endpoint(file_path: file_path)
    end

    # Backward-compatible alias for older Rails installs.
    def mobile(file_path)
      app(file_path)
    end
  end

  module Rails
    # ViewRouter dispatches incoming page connections to the correct RufletView
    # subclass based on the current route.  It includes SharedControlForwarders
    # so that widget helpers (text, column, safe_area, …) can be called directly
    # inside its own rendering helpers — the same pattern showcase uses.
    class ViewRouter
      include Ruflet::UI::SharedControlForwarders

      def initialize(page, routes: nil, default: nil)
        @page = page
        @routes = normalize_routes(routes || self.class.discovered_routes)
        @default = default || @routes["/"]
      end

      def start
        @page.on_route_change = ->(_event) { render }
        render
      end

      def render
        if root_route_without_default?
          render_route_index
          return
        end

        target = route_target(@page.route)

        if target.respond_to?(:render)
          target.render(@page)
        elsif target.respond_to?(:call)
          target.call(@page)
        else
          render_empty_state
        end
      end

      def self.discovered_routes
        Ruflet::Rails.view_classes.each_with_object({}) do |view_class, routes|
          next unless view_class.respond_to?(:route)

          routes[view_class.route] = view_class
        end
      end

      private

      # Widget builder calls delegate to the global DSL, same as Kernel does,
      # keeping the showcase pattern consistent across all contexts.
      def control_delegate
        Ruflet::DSL
      end

      def route_target(route)
        path = route_path(route)
        return @routes[path] if @routes.key?(path)
        return @default if path == "/"

        nil
      end

      def root_route_without_default?
        route_path(@page.route) == "/" && @default.nil? && @routes["/"].nil? && @routes.any?
      end

      def normalize_routes(routes)
        routes.to_h.transform_keys { |path| normalize_route(path) }
      end

      def route_path(route)
        normalize_route(route.to_s.split("?", 2).first)
      end

      def normalize_route(path)
        value = path.to_s.strip
        return "/" if value.empty? || value == "/"

        "/#{value.gsub(%r{\A/+|/+\z}, "")}"
      end

      def render_empty_state
        @page.title = "Ruflet"
        @page.add(
          container(
            expand: true,
            alignment: Ruflet::MainAxisAlignment::CENTER,
            content: text("No Ruflet views found")
          )
        )
        @page.update
      end

      def render_route_index
        @page.title = "Ruflet"
        @page.add(
          safe_area(
            container(
              expand: true,
              padding: { left: 24, top: 16, right: 24, bottom: 24 },
              content: column(
                spacing: 12,
                controls: [
                  text("Ruflet", size: 24, weight: "bold"),
                  *route_index_buttons
                ]
              )
            ),
            expand: true
          )
        )
        @page.update
      end

      def route_index_buttons
        @routes.keys.sort.map do |path|
          filled_button(
            content: text(route_label(path)),
            on_click: ->(_event) { @page.go(path) }
          )
        end
      end

      def route_label(path)
        label = path.to_s.delete_prefix("/").tr("_-", " ")
        label.empty? ? "Home" : label.split.map(&:capitalize).join(" ")
      end
    end
  end
end
