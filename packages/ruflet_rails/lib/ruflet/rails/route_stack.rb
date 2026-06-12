# frozen_string_literal: true

module Ruflet
  module Rails
    # Flet-style routed navigation stack for complex, multi-screen apps.
    #
    # It wires up the boilerplate that Flet's routing examples spell out by hand
    # — on_route_change, on_view_pop and the initial page.go — so an app only has
    # to describe, per route, how to build that screen's View stack. The stack is
    # rebuilt from the current route on every navigation, and the client back
    # button (AppBar arrow / system back) pops it automatically.
    #
    # Block form — one builder receives the current route and the stack:
    #
    #   Ruflet::Rails.routed(page) do |route, nav|
    #     nav.push(home_view)
    #     nav.push(store_view) if route == "/store"
    #   end
    #
    # Map form — declare a builder per route:
    #
    #   Ruflet::Rails::RouteStack.new(page)
    #     .on("/")      { |nav| nav.push(home_view) }
    #     .on("/store") { |nav| nav.push(home_view); nav.push(store_view) }
    #     .start
    #
    # Navigate with page.go("/store"); pushing onto the stack happens by
    # rebuilding for the new route, exactly like Flet.
    class RouteStack
      def initialize(page, &builder)
        @page = page
        @builder = builder
        @routes = {}
        @stack = []
        wire_page_handlers!
      end

      # Register a per-route stack builder. The block receives this RouteStack so
      # it can #push one or more views for that route.
      def on(route, &block)
        @routes[normalize(route)] = block
        self
      end

      # Append a View (or anything responding to #route) onto the current stack.
      def push(view)
        @stack << view
        view
      end

      # Render the current route's stack and begin listening for navigation.
      def start
        @page.go(@page.route.to_s.empty? ? "/" : @page.route)
        self
      end

      private

      def wire_page_handlers!
        @page.on_route_change = ->(_event) { rebuild }
        @page.on_view_pop = lambda do |_event|
          @page.views.pop
          top = @page.views.last
          @page.go(top.respond_to?(:route) ? top.route : "/")
        end
      end

      def rebuild
        @stack = []
        route = normalize(@page.route.to_s.split("?", 2).first)

        if @builder
          @builder.call(route, self)
        elsif (block = @routes[route])
          block.call(self)
        end

        @page.views = @stack
        @page.update
      end

      def normalize(route)
        value = route.to_s.strip
        return "/" if value.empty? || value == "/"

        "/#{value.gsub(%r{\A/+|/+\z}, "")}"
      end
    end
  end
end
