# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      # Rack middleware that intercepts WebSocket upgrade requests at the
      # configured ws_path and hands them off to a Ruflet::Rails::Protocol::Endpoint.
      #
      # When Ruflet::Rails is configured with an app_file and ws_path the Railtie
      # inserts this middleware automatically — no `mount` is needed in routes.rb.
      #
      # Regular (non-WebSocket) GET requests pass through untouched so the rest
      # of the Rails stack (routes, static files, etc.) works normally.
      class Middleware
        def initialize(app, path: nil, entrypoint_path: nil)
          @app      = app
          @path     = path
          @endpoint = entrypoint_path ? build_endpoint(entrypoint_path) : nil
        end

        def call(env)
          Context.with_env(env) do
            if ruflet_request?(env)
              @endpoint.call(env)
            else
              @app.call(env)
            end
          end
        end

        private

        def ruflet_request?(env)
          @endpoint &&
            @path &&
            env["PATH_INFO"] == @path &&
            websocket_upgrade?(env)
        end

        def websocket_upgrade?(env)
          return false unless env["REQUEST_METHOD"] == "GET"

          upgrade    = env["HTTP_UPGRADE"].to_s.downcase
          connection = env["HTTP_CONNECTION"].to_s.downcase
          key        = env["HTTP_SEC_WEBSOCKET_KEY"].to_s

          upgrade == "websocket" && connection.include?("upgrade") && !key.empty?
        end

        def build_endpoint(entrypoint_path)
          Runner.new.build_app_endpoint(file_path: entrypoint_path.to_s, path: @path)
        end
      end
    end
  end
end
