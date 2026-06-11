# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      # Self-contained Rack application for a Ruflet web frontend: serves the
      # built Flutter web client AND speaks the Ruflet WebSocket protocol on
      # the same mount point, so it mounts like any Rack app:
      #
      #   # config/routes.rb
      #   mount Ruflet::Rails.web_app, at: "/myfrontend"
      #
      #   # or with an explicit entrypoint and build directory:
      #   mount Ruflet::Rails.web_app(build_dir: Rails.root.join("public/app")) { |page|
      #     CounterView.render(page)
      #   }, at: "/myfrontend"
      #
      # How it stays mount-point independent: the Flutter web client derives
      # both its asset URLs and its WebSocket URL from `Uri.base`, which comes
      # from index.html's <base href>. This app rewrites <base href> to the
      # actual mount point on the fly, so the same build works under any
      # route — the client then connects its WebSocket back to the mount
      # point, where the upgrade is answered via Rack hijack by the shared
      # Ruflet::ConnectionProtocol engine running on the Rails server itself.
      class WebApp
        include WebSocketDetection

        CONTENT_TYPES = {
          ".html" => "text/html; charset=utf-8",
          ".js" => "application/javascript",
          ".mjs" => "application/javascript",
          ".css" => "text/css",
          ".json" => "application/json",
          ".wasm" => "application/wasm",
          ".png" => "image/png",
          ".jpg" => "image/jpeg",
          ".jpeg" => "image/jpeg",
          ".gif" => "image/gif",
          ".webp" => "image/webp",
          ".svg" => "image/svg+xml",
          ".ico" => "image/x-icon",
          ".otf" => "font/otf",
          ".ttf" => "font/ttf",
          ".woff" => "font/woff",
          ".woff2" => "font/woff2",
          ".map" => "application/json",
          ".txt" => "text/plain"
        }.freeze

        def initialize(build_dir: nil, entrypoint: nil, &app_block)
          @explicit_build_dir = build_dir
          @entrypoint_option = entrypoint
          @app_block = app_block
          @endpoint = nil
          @endpoint_mutex = Mutex.new
        end

        def call(env)
          return websocket_endpoint.call(env) if websocket_upgrade?(env)

          path = env["PATH_INFO"].to_s
          return serve_index(env) if ["", "/", "/index.html"].include?(path)

          serve_static(path)
        end

        private

        def websocket_endpoint
          @endpoint_mutex.synchronize do
            @endpoint ||= Runner.new(&entrypoint).build_endpoint
          end
        end

        def entrypoint
          @entrypoint_option || @app_block || lambda { |page| Ruflet::Rails.render(page) }
        end

        def build_dir
          explicit = @explicit_build_dir.to_s
          return explicit unless explicit.empty?

          configured = Ruflet::Rails.config.web_build_dir.to_s
          return configured unless configured.empty?

          default = defined?(::Rails.root) && ::Rails.root ? ::Rails.root.join("public", "app").to_s : nil
          default.to_s
        end

        def serve_index(env)
          index_path = File.join(build_dir, "index.html")
          unless File.file?(index_path)
            return [404, { "content-type" => "text/plain" },
                    ["Ruflet web build not found at #{index_path}. Run `rake ruflet:build[web]`."]]
          end

          html = rewrite_base_href(File.read(index_path), mount_base(env))
          html = inject_mount_url_param(html)
          [200,
           { "content-type" => "text/html; charset=utf-8",
             "cache-control" => "no-cache",
             "content-length" => html.bytesize.to_s },
           [html]]
        end

        # The Flet web client builds its WebSocket URL as
        # ws(s)://<page authority>/<window.flet.webSocketEndpoint || "ws">.
        # Without help, every build connects to the origin's /ws and escapes
        # the mount. Deriving the endpoint from document.baseURI (which
        # follows the rewritten <base href>) pins any build to <mount>/ws —
        # answered by this same Rack app.
        MOUNT_URL_BOOTSTRAP = <<~HTML
          <script>
            (function () {
              window.flet = window.flet || {};
              if (!window.flet.webSocketEndpoint) {
                var basePath = new URL(document.baseURI).pathname;
                window.flet.webSocketEndpoint = (basePath + "ws").replace(/^\\/+/, "");
              }
            })();
          </script>
        HTML

        def inject_mount_url_param(html)
          return html if html.include?("window.flet.webSocketEndpoint")

          html.sub(%r{(<base\s+href="[^"]*"\s*/?>)}) { "#{::Regexp.last_match(1)}\n#{MOUNT_URL_BOOTSTRAP}" }
        end

        # <base href> drives the Flutter client's asset and WebSocket URLs;
        # pin it to the actual mount point so one build serves any route.
        def rewrite_base_href(html, base)
          if html =~ %r{<base\s+href="[^"]*"\s*/?>}
            html.sub(%r{<base\s+href="[^"]*"\s*/?>}, "<base href=\"#{base}\">")
          else
            html.sub(/<head>/i, "<head>\n  <base href=\"#{base}\">")
          end
        end

        def mount_base(env)
          script = env["SCRIPT_NAME"].to_s
          return "/" if script.empty? || script == "/"

          script.end_with?("/") ? script : "#{script}/"
        end

        def serve_static(path)
          root = File.expand_path(build_dir)
          full = File.expand_path(File.join(root, path))
          unless full.start_with?(root + File::SEPARATOR) && File.file?(full)
            return [404, { "content-type" => "text/plain" }, ["Not Found"]]
          end

          body = File.binread(full)
          [200,
           { "content-type" => content_type_for(full),
             "content-length" => body.bytesize.to_s },
           [body]]
        end

        def content_type_for(path)
          CONTENT_TYPES.fetch(File.extname(path).downcase, "application/octet-stream")
        end
      end
    end
  end
end
