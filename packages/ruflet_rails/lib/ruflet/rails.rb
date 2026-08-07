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

    # WebSocket endpoint for native clients (Ruflet Explorer, or a built
    # mobile/desktop app). You own the Ruflet entrypoint explicitly; there is
    # no Rails component discovery:
    #
    #   # a standalone Ruflet app file (Ruflet.run/MyApp.new.run), per session:
    #   match "/ws", to: Ruflet::Rails.native(Rails.root.join("app/ruflet/main.rb")), via: :all
    #
    #   # or a custom block:
    #   match "/ws", to: Ruflet::Rails.native { |page| MyHome.render(page) }, via: :all
    #
    # One of an app file (positional) or a block is required.
    def native(app_file = nil, &block)
      sources = [app_file, block].compact
      raise ArgumentError, "native accepts only one of an app file or a block" if sources.length > 1
      raise ArgumentError, "native requires an app file or a block" if sources.empty?

      return Protocol::Runner.new.build_app_endpoint(file_path: app_file) if app_file

      Protocol::Runner.new(&block).build_endpoint
    end

    # Self-contained web frontend (the Flutter web build plus the Ruflet
    # WebSocket on one mount), for browser clients. Serves the build with
    # <base href> rewritten to the mount point; routes stay routing-only:
    #
    #   # a standalone Ruflet app file (MyApp.new.run), loaded per session:
    #   mount Ruflet::Rails.web(app_file: "app/ruflet/showcase/main.rb"), at: "/showcase"
    #
    #   # or a custom block:
    #   mount Ruflet::Rails.web { |page| MyHome.render(page) }, at: "/app"
    #
    # One of app_file: or a block is required.
    def web(app_file: nil, build_dir: nil, &app_block)
      sources = [app_file, app_block].compact
      raise ArgumentError, "web accepts only one of app_file: or a block" if sources.length > 1
      raise ArgumentError, "web requires one of app_file: or a block" if sources.empty?

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
