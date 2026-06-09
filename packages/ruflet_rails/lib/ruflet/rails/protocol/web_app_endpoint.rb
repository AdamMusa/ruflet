# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      # Rack endpoint that serves the pre-built Flutter web app's index.html.
      #
      # The HTML is read from build_dir and returned as-is — no mutation.
      # The backend URL is baked into the build at compile time via:
      #
      #   rake ruflet:build[web]   # reads backend_url from ruflet.yaml
      #
      # which passes --dart-define=RUFLET_URL=<backend_url> to flutter build.
      # The Flutter client reads it via String.fromEnvironment('RUFLET_URL').
      #
      # Static assets (JS, WASM, fonts) in the build dir are served by Rails'
      # ActionDispatch::Static as normal.
      #
      # Usage in routes.rb:
      #
      #   match "/ws",       to: Ruflet::Rails.app(Rails.root.join("app/views/mobile/main.rb")), via: :all
      #   get   "/showcase", to: Ruflet::Rails.web(build: Rails.root.join("public/showcase"))
      #
      class WebAppEndpoint
        def initialize(build_dir:)
          @index_path = File.join(build_dir.to_s, "index.html")
        end

        def call(_env)
          return not_found unless File.file?(@index_path)

          html = File.read(@index_path)
          [200, { "content-type" => "text/html; charset=utf-8", "content-length" => html.bytesize.to_s }, [html]]
        end

        private

        def not_found
          [404, { "content-type" => "text/plain" }, ["Web build not found"]]
        end
      end
    end
  end
end
