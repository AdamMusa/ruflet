# frozen_string_literal: true

module Ruflet
  module Rails
    module_function

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
    class ViewRouter
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

      def route_target(route)
        path = route_path(route)
        @routes[path] || @routes[first_segment(path)] || @default || @routes.values.first
      end

      def normalize_routes(routes)
        routes.to_h.transform_keys { |path| normalize_route(path) }
      end

      def route_path(route)
        normalize_route(route.to_s.split("?", 2).first)
      end

      def first_segment(path)
        parts = path.split("/").reject(&:empty?)
        parts.empty? ? "/" : "/#{parts.first}"
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
    end
  end
end
