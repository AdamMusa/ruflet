# frozen_string_literal: true

require "digest/sha1"

module Ruflet
  module Rails
    module Protocol
      class Endpoint
        include WebSocketDetection

        WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

        def initialize(server:, path: nil)
          @server = server
          @path = path
        end

        def call(env)
          return not_found if @path && env["PATH_INFO"] != @path
          return bad_request("Expected WebSocket upgrade") unless websocket_upgrade?(env)
          return forbidden("Origin not allowed") unless websocket_origin_allowed?(env)

          hijack = env["rack.hijack"]
          return bad_request("Rack hijack is required by Ruflet::Rails::Protocol::Endpoint") unless hijack.respond_to?(:call)

          hijack.call
          io = env["rack.hijack_io"]
          return bad_request("Rack did not provide hijacked IO") unless io

          io.sync = true if io.respond_to?(:sync=)
          write_handshake(io, env["HTTP_SEC_WEBSOCKET_KEY"])

          captured_env = env.dup
          Thread.new(io, captured_env) do |socket, ws_env|
            Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
            if server_runs_messages_in_rails_executor?
              handle_socket(socket, ws_env)
            else
              rails_executor_wrap { handle_socket(socket, ws_env) }
            end
          end

          [-1, {}, []]
        rescue StandardError => e
          [500, { "content-type" => "text/plain" }, ["Ruflet Rails protocol error: #{e.message}"]]
        end

        private

        # A browser sends Origin with every WebSocket handshake; native
        # clients send none. An Origin that is neither the app's own address
        # nor localhost is logged once, and accepted as before until
        # Ruflet::Rails.config.allowed_origins (or RUFLET_ALLOWED_ORIGINS) is
        # set. Once it is, other foreign origins get a 403. See
        # Ruflet::OriginPolicy.
        def websocket_origin_allowed?(env)
          policy = origin_policy
          return true unless policy

          policy.allow?(env["HTTP_ORIGIN"], [env["HTTP_HOST"], env["HTTP_X_FORWARDED_HOST"]])
        end

        # Built on the first upgrade, after the app's initializers have run.
        def origin_policy
          return @origin_policy if @origin_policy_resolved

          @origin_policy = build_origin_policy
          @origin_policy_resolved = true
          @origin_policy
        end

        def build_origin_policy
          # ruflet_server releases older than the origin check have no
          # OriginPolicy; keep accepting every origin with those.
          return nil unless defined?(Ruflet::OriginPolicy)

          Ruflet::OriginPolicy.new(
            allowed_origins: Ruflet::OriginPolicy.entries(
              Ruflet::Rails.config.allowed_origins, ENV["RUFLET_ALLOWED_ORIGINS"]
            ),
            setting_hint: "Ruflet::Rails.config.allowed_origins (or RUFLET_ALLOWED_ORIGINS)",
            log: method(:log_origin_warning)
          )
        end

        def log_origin_warning(message)
          if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
            ::Rails.logger.warn(message)
          else
            warn message
          end
        end

        def handle_socket(socket, env)
          Context.with_env(env) do
            @server.handle_upgraded_socket(socket)
          end
        end

        # LocalServer (what Ruflet::Rails.native mounts) runs each message in
        # its own executor run. Another server passed in keeps the previous
        # whole-socket wrap.
        def server_runs_messages_in_rails_executor?
          @server.respond_to?(:runs_messages_in_rails_executor?) && @server.runs_messages_in_rails_executor?
        end

        def rails_executor_wrap(&block)
          executor = if defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application
                       ::Rails.application.executor
                     end

          if executor.respond_to?(:wrap)
            executor.wrap(&block)
          else
            yield
          end
        end

        def write_handshake(io, key)
          accept = [Digest::SHA1.digest("#{key}#{WEBSOCKET_GUID}")].pack("m0")

          io.write("HTTP/1.1 101 Switching Protocols\r\n")
          io.write("Upgrade: websocket\r\n")
          io.write("Connection: Upgrade\r\n")
          io.write("Sec-WebSocket-Accept: #{accept}\r\n")
          io.write("\r\n")
        end

        def not_found
          [404, { "content-type" => "text/plain" }, ["Not Found"]]
        end

        def bad_request(message)
          [400, { "content-type" => "text/plain" }, [message]]
        end

        def forbidden(message)
          [403, { "content-type" => "text/plain" }, [message]]
        end
      end
    end
  end
end
