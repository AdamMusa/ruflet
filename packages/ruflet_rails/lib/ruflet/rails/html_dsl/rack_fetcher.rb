# frozen_string_literal: true

require "uri"
require "stringio"

module Ruflet
  module Rails
    module HtmlDsl
      # Screen source for erb_to_native: renders Rails views by dispatching
      # straight into the Rack app (`Rails.application`) — routing, controller,
      # then view. This is what gives the developer a real controller: params,
      # `before_action`s, saving a form, loading records, assigning `@ivars`,
      # then rendering the ERB screen.
      #
      # It is NOT network HTTP. There is no socket and no second connection —
      # it's a function call on the WebSocket session's own thread, so it can't
      # stall the read loop or drop the connection the way a blocking
      # `Net::HTTP` self-request would. Screens navigate by URL (`/native`,
      # `/counter`), and form POSTs round-trip through the controller.
      class RackFetcher
        Response = Struct.new(:status, :body, :url, keyword_init: true)
        MAX_REDIRECTS = 5
        REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze

        def initialize(app: nil)
          @app = app
          @cookies = {}
        end

        def fetch(method, url, params: nil, headers: {})
          method = method.to_s.upcase
          redirects = 0

          loop do
            status, response_headers, body = rack_app.call(build_env(method, url, params, headers))
            store_cookies(response_headers)
            location = header(response_headers, "location")

            unless REDIRECT_STATUSES.include?(status.to_i) && location
              return Response.new(status: status.to_i, body: read_body(body), url: url)
            end

            close_body(body)
            redirects += 1
            raise "Too many redirects fetching #{url}" if redirects > MAX_REDIRECTS

            url = URI.join(url, location).to_s
            # 307/308 preserve the method and body; everything else becomes a GET.
            unless %w[307 308].include?(status.to_s)
              method = "GET"
              params = nil
            end
          end
        end

        private

        def rack_app
          @app ||= ::Rails.application
        end

        # A minimal-but-complete Rack env, built by hand so we don't depend on a
        # particular Rack version's Rack::MockRequest location.
        def build_env(method, url, params, headers)
          uri = URI.parse(url)
          query = uri.query
          body = ""
          content_type = nil

          if params && !params.empty?
            encoded = URI.encode_www_form(params)
            if method == "GET"
              query = [query, encoded].reject { |part| part.to_s.empty? }.join("&")
            else
              body = encoded
              content_type = "application/x-www-form-urlencoded"
            end
          end

          env = {
            "REQUEST_METHOD" => method,
            "SCRIPT_NAME" => "",
            "PATH_INFO" => uri.path.to_s.empty? ? "/" : uri.path,
            "QUERY_STRING" => query.to_s,
            "SERVER_NAME" => uri.host || "localhost",
            "SERVER_PORT" => (uri.port || (uri.scheme == "https" ? 443 : 80)).to_s,
            "HTTP_HOST" => [uri.host, uri.port].compact.join(":"),
            # These renders happen in-process on the server itself — a loopback
            # request in every sense. Saying so keeps `request.remote_ip` sane and
            # quiets dev middleware (web-console) on every screen.
            "REMOTE_ADDR" => "127.0.0.1",
            "rack.url_scheme" => uri.scheme || "http",
            "rack.input" => StringIO.new(body),
            "rack.errors" => $stderr,
            "rack.multithread" => true,
            "rack.multiprocess" => false,
            "rack.run_once" => false,
            "HTTP_ACCEPT" => "text/html",
            "HTTP_X_RUFLET_NATIVE" => "1"
          }
          env["CONTENT_TYPE"] = content_type if content_type
          env["CONTENT_LENGTH"] = body.bytesize.to_s unless body.empty?
          env["HTTP_COOKIE"] = cookie_header unless @cookies.empty?
          headers.each { |key, value| env["HTTP_#{key.to_s.upcase.tr('-', '_')}"] = value.to_s }
          env
        end

        def read_body(body)
          buffer = +""
          body.each { |chunk| buffer << chunk.to_s }
          buffer.force_encoding(Encoding::UTF_8) if buffer.encoding == Encoding::ASCII_8BIT
          buffer
        ensure
          close_body(body)
        end

        def close_body(body)
          body.close if body.respond_to?(:close)
        rescue StandardError
          nil
        end

        # Thread the Rails session cookie between sub-requests so CSRF tokens and
        # flashes survive a form POST -> redirect -> render, like a browser.
        def store_cookies(response_headers)
          set_cookie = header(response_headers, "set-cookie")
          return unless set_cookie

          Array(set_cookie).each do |cookie|
            cookie.to_s.split("\n").each do |line|
              pair = line.split(";", 2).first.to_s.strip
              name, value = pair.split("=", 2)
              @cookies[name] = value if name && value
            end
          end
        end

        def cookie_header
          @cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
        end

        # Rack 3 lower-cases header names; earlier versions title-case them.
        def header(response_headers, name)
          return nil unless response_headers

          response_headers[name] || response_headers[name.split("-").map(&:capitalize).join("-")] ||
            (response_headers.respond_to?(:find) &&
             response_headers.find { |key, _| key.to_s.downcase == name }&.last)
        end
      end
    end
  end
end
