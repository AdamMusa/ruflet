# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      # Rack middleware inserted before ActionDispatch::Static by the Railtie.
      #
      # Responsibilities:
      #   1. WebSocket at ws_path (/ws) — native mobile/desktop clients.
      #   2. WebSocket at the build dir base path (e.g. /app, /app/) — the
      #      Flutter web client uses Uri.base from <base href="/app/"> as its
      #      connection URL, so it naturally connects back to /app/ as WebSocket.
      #      No URL injection needed — the client finds the server on its own.
      #   3. Block direct HTTP access to the build dir's index so
      #      ActionDispatch::Static never leaks it at /app — serves Rails' 404.
      class Middleware
        INDEX_SUFFIXES = ["", "/", "/index.html"].freeze

        def initialize(app)
          @app         = app
          @ws_endpoint = nil
        end

        def call(env)
          cfg  = Ruflet::Rails.config
          path = env["PATH_INFO"].to_s

          if cfg.app_file
            # WS at configured ws_path — native/desktop clients
            if cfg.ws_path && path == normalize(cfg.ws_path) && websocket_upgrade?(env)
              return Context.with_env(env) { ws_endpoint(cfg).call(env) }
            end

            # WS at build dir base path — Flutter web client (Uri.base = /app/)
            if cfg.web_build_dir && build_dir_base?(path, cfg.web_build_dir.to_s) && websocket_upgrade?(env)
              return Context.with_env(env) { ws_endpoint(cfg).call(env) }
            end
          end

          # Block direct HTTP access to the build dir index
          if cfg.web_build_dir && build_dir_index?(path, cfg.web_build_dir.to_s)
            return rails_404
          end

          Context.with_env(env) { @app.call(env) }
        end

        private

        def ws_endpoint(cfg)
          @ws_endpoint ||= Runner.new.build_app_endpoint(file_path: cfg.app_file.to_s)
        end

        def websocket_upgrade?(env)
          return false unless env["REQUEST_METHOD"] == "GET"

          env["HTTP_UPGRADE"].to_s.downcase == "websocket" &&
            env["HTTP_CONNECTION"].to_s.downcase.include?("upgrade") &&
            env["HTTP_SEC_WEBSOCKET_KEY"].to_s != ""
        end

        # Matches /app and /app/ — the Flutter web client connects here.
        def build_dir_base?(path, build_dir)
          base = "/#{File.basename(build_dir)}"
          path == base || path == "#{base}/"
        end

        # Matches /app, /app/, /app/index.html — blocks static serving of index.
        def build_dir_index?(path, build_dir)
          base = "/#{File.basename(build_dir)}"
          INDEX_SUFFIXES.any? { |suffix| path == "#{base}#{suffix}" }
        end

        def rails_404
          page = rails_404_page
          [404, { "content-type" => "text/html; charset=utf-8", "content-length" => page.bytesize.to_s }, [page]]
        end

        def rails_404_page
          path = defined?(::Rails) ? ::Rails.public_path.join("404.html") : nil
          path && File.file?(path) ? File.read(path) : "Not Found"
        end

        def normalize(path)
          "/#{path.to_s.gsub(%r{\A/+|/+\z}, "")}"
        end
      end
    end
  end
end
