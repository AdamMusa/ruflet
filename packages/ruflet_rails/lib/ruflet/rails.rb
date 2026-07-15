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

    def sessions
      @sessions ||= SessionRegistry.new
    end

    def broadcast(&block)
      sessions.broadcast(&block)
    end

    # WebSocket endpoint for native mobile/desktop clients. The developer owns
    # the Ruflet entrypoint explicitly; there is no Rails component discovery:
    #
    #   # a standalone Ruflet app file (Ruflet.run/MyApp.new.run), per session:
    #   match "/ws", to: Ruflet::Rails.endpoint(app_file: Rails.root.join("app/ruflet/main.rb")), via: :all
    #
    #   # a custom block:
    #   match "/ws", to: Ruflet::Rails.endpoint { |page| MyHome.render(page) }, via: :all
    #
    # One of app_file: or a block is required.
    def endpoint(app_file: nil, &block)
      sources = [app_file, block].compact
      raise ArgumentError, "endpoint accepts only one of app_file: or a block" if sources.length > 1
      raise ArgumentError, "endpoint requires one of app_file: or a block" if sources.empty?

      return Protocol::Runner.new.build_app_endpoint(file_path: app_file) if app_file

      Protocol::Runner.new(&block).build_endpoint
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
    #   # a standalone Ruflet app file (MyApp.new.run), loaded per session:
    #   mount Ruflet::Rails.web_app(app_file: "app/ruflet/showcase/main.rb"), at: "/showcase"
    #
    #   # a custom block:
    #   mount Ruflet::Rails.web_app { |page| MyHome.render(page) }, at: "/app"
    #
    # One of app_file: or a block is required.
    def web_app(app_file: nil, build_dir: nil, &app_block)
      sources = [app_file, app_block].compact
      raise ArgumentError, "web_app accepts only one of app_file: or a block" if sources.length > 1
      raise ArgumentError, "web_app requires one of app_file: or a block" if sources.empty?

      Protocol::WebApp.new(
        build_dir: build_dir,
        entrypoint: web_app_entrypoint(app_file: app_file),
        &app_block
      )
    end

    def web_app_entrypoint(app_file: nil)
      return unless app_file

      absolute = app_file.to_s
      lambda do |page, env|
        loaded = Protocol::MobileLoader.new(File.expand_path(absolute)).load!
        entry = loaded[:entrypoint]
        entry.arity == 1 ? entry.call(page) : entry.call(page, env)
      end
    end

  end
end
