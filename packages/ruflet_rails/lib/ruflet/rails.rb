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

  end
end
