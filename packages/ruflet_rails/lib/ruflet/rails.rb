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
    #     c.backend_url = "https://example.com"
    #   end
    def configure
      yield config
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

    def sessions
      @sessions ||= SessionRegistry.new
    end

    def broadcast(&block)
      sessions.broadcast(&block)
    end

    # WebSocket endpoint for native mobile/desktop clients. The developer
    # declares the entry the same way they declare a web mount — the screens
    # the app shows live in dev code, never in framework auto-discovery:
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
    # One of view:, app_file:, or a block is required — there is no
    # auto-discovery fallback.
    def endpoint(view: nil, app_file: nil, &block)
      sources = [view, app_file, block].compact
      raise ArgumentError, "endpoint accepts only one of view:, app_file:, or a block" if sources.length > 1
      raise ArgumentError, "endpoint requires one of view:, app_file:, or a block" if sources.empty?

      return Protocol::Runner.new.build_app_endpoint(file_path: app_file) if app_file

      entry = block || web_app_entrypoint(view: view)
      Protocol::Runner.new(&entry).build_endpoint
    end

    # Shorthand for a standalone app-file endpoint.
    #
    #   match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/ruflet/main.rb")), via: :all
    def app(file_path)
      endpoint(app_file: file_path)
    end

    # Self-contained web frontend, mountable under any route. Serves the
    # Flutter web build (with <base href> rewritten to the mount point) and
    # answers the Ruflet WebSocket on the same path. Routes stay routing-only;
    # UI code lives in dev files:
    #
    #   # a single view class (resolved lazily, so reloading works):
    #   mount Ruflet::Rails.web_app(view: "CounterView"), at: "/myfrontend"
    #
    #   # a standalone Ruflet app file (MyApp.new.run), loaded per session:
    #   mount Ruflet::Rails.web_app(app_file: "app/ruflet/showcase/main.rb"), at: "/showcase"
    #
    #   # a custom block:
    #   mount Ruflet::Rails.web_app { |page| MyHome.render(page) }, at: "/app"
    #
    # One of view:, app_file:, or a block is required — there is no
    # auto-discovery fallback.
    def web_app(view: nil, app_file: nil, build_dir: nil, &app_block)
      sources = [view, app_file, app_block].compact
      raise ArgumentError, "web_app accepts only one of view:, app_file:, or a block" if sources.length > 1
      raise ArgumentError, "web_app requires one of view:, app_file:, or a block" if sources.empty?

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

  end
end
