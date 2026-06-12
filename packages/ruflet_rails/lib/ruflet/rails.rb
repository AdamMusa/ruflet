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

    # Flet-style routed navigation stack for complex multi-screen apps. Wires
    # up on_route_change / on_view_pop and starts at the current route. See
    # Ruflet::Rails::RouteStack.
    #
    #   Ruflet::Rails.routed(page) do |route, nav|
    #     nav.push(home_view)
    #     nav.push(store_view) if route == "/store"
    #   end
    def routed(page, &builder)
      RouteStack.new(page, &builder).start
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

    # WebSocket endpoint for native mobile/desktop clients. The developer
    # declares the entry the same way they declare a web mount — so the screens
    # the app shows live in dev code, not in framework auto-discovery:
    #
    #   # a standalone Ruflet app file (Ruflet.run/MyApp.new.run), per session:
    #   match "/ws", to: Ruflet::Rails.endpoint(app_file: Rails.root.join("app/ruflet/main.rb")), via: :all
    #
    #   # a single component/view class (resolved lazily, so reloading works):
    #   match "/ws", to: Ruflet::Rails.endpoint(view: "ProductComponent"), via: :all
    #
    #   # a custom block:
    #   match "/ws", to: Ruflet::Rails.endpoint { |page| MyHome.render(page) }, via: :all
    #
    # With nothing declared it falls back to the convenience view router, which
    # auto-discovers RufletView subclasses and renders a route index. That index
    # is a framework fallback for the zero-config case — declare an entry above
    # to own the home screen in your code.
    def endpoint(view: nil, app_file: nil, &block)
      sources = [view, app_file, block].compact
      raise ArgumentError, "endpoint accepts only one of view:, app_file:, or a block" if sources.length > 1

      return Protocol::Runner.new.build_app_endpoint(file_path: app_file) if app_file

      entry =
        if block
          block
        elsif view
          web_app_entrypoint(view: view)
        else
          ->(page) { render(page) }
        end
      Protocol::Runner.new(&entry).build_endpoint
    end

    # Backward-compatible shorthand for a standalone app-file mobile endpoint.
    #
    #   match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/ruflet/main.rb")), via: :all
    def app(file_path)
      endpoint(app_file: file_path)
    end

    # Backward-compatible alias for older Rails installs.
    def mobile(file_path)
      app(file_path)
    end

    # Serves the pre-built Flutter web build's index.html at the given route.
    # Static assets (JS, WASM, fonts) are served by ActionDispatch::Static.
    #
    # Usage in routes.rb:
    #   get "/showcase", to: Ruflet::Rails.web(build: Rails.root.join("public/showcase"))
    def web(build:)
      Protocol::WebAppEndpoint.new(build_dir: build.to_s)
    end

    # Self-contained web frontend, mountable under any route. Serves the
    # Flutter web build (with <base href> rewritten to the mount point) and
    # answers the Ruflet WebSocket on the same path. Routes stay routing-only;
    # UI code lives in app/views/ruflet:
    #
    #   # all registered RufletView subclasses behind the view router:
    #   mount Ruflet::Rails.web_app, at: "/app"
    #
    #   # a single view class (resolved lazily, so reloading works):
    #   mount Ruflet::Rails.web_app(view: "CounterView"), at: "/myfrontend"
    #
    #   # a standalone Ruflet app file (MyApp.new.run), loaded per session:
    #   mount Ruflet::Rails.web_app(app_file: "app/ruflet/showcase/main.rb"), at: "/showcase"
    def web_app(view: nil, app_file: nil, build_dir: nil, &app_block)
      sources = [view, app_file, app_block].compact
      raise ArgumentError, "web_app accepts only one of view:, app_file:, or a block" if sources.length > 1

      Protocol::WebApp.new(
        build_dir: build_dir,
        entrypoint: web_app_entrypoint(view: view, app_file: app_file),
        &app_block
      )
    end

    def web_app_entrypoint(view: nil, app_file: nil)
      if view
        lambda do |page|
          view_class_for(view).render(page)
        end
      elsif app_file
        absolute = app_file.to_s
        lambda do |page, env|
          loaded = Protocol::MobileLoader.new(File.expand_path(absolute)).load!
          entry = loaded[:entrypoint]
          entry.arity == 1 ? entry.call(page) : entry.call(page, env)
        end
      end
    end

    # Resolved lazily on each session so Rails code reloading picks up edits.
    def view_class_for(view)
      return view if view.is_a?(Class)

      view.to_s.constantize
    end

    # Reads index.html from the web build dir, injects window.__RUFLET_URL__
    # from config.backend_url so the Flutter client knows the WS backend
    # without a rebuild. Falls back to the request base_url if not configured.
    #
    # Usage in a Rails controller:
    #   render html: Ruflet::Rails.web_html(request), layout: false
    def web_html(request)
      build_dir = config.web_build_dir.to_s
      html      = File.read(File.join(build_dir, "index.html"))
      url       = config.backend_url.to_s.strip
      url       = request.base_url if url.empty?
      script    = "<script>window.__RUFLET_URL__=#{url.to_json};</script>"
      html.include?("</head>") ? html.sub("</head>", "#{script}</head>") : "#{script}#{html}"
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
