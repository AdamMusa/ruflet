# frozen_string_literal: true

module Ruflet
  module Rails
    # Central configuration for ruflet_rails.
    #
    # Set in an initializer:
    #
    #   # config/initializers/ruflet.rb
    #   Ruflet::Rails.configure do |config|
    #     config.app_file = Rails.root.join("app/views/ruflet/main.rb")
    #     config.ws_path  = "/ws"   # default
    #   end
    #
    # With this in place, no `mount` is needed in config/routes.rb — the
    # Railtie inserts the WebSocket endpoint as Rack middleware automatically.
    class Configuration
      # Absolute path to the Ruflet app entry-point (the file passed to
      # Ruflet.run). Required for the Railtie auto-mount to work.
      attr_accessor :app_file

      # URL path the WebSocket endpoint listens on. Defaults to "/ws".
      # The Ruflet web client bootstrap uses this same path so the Flutter
      # web app always connects to the right endpoint.
      attr_accessor :ws_path

      def initialize
        @ws_path  = "/ws"
        @app_file = nil
      end
    end
  end
end
