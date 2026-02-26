# frozen_string_literal: true

require "digest/sha1"

module Ruflet
  module Rails
    module Protocol
      class Endpoint
        WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

        def initialize(server:, path: "/ws")
          @server = server
          @path = path
        end

        def call(env)
          return not_found unless env["PATH_INFO"] == @path
          return bad_request("Expected WebSocket upgrade") unless websocket_upgrade_request?(env)

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
            Context.with_env(ws_env) do
              @server.handle_upgraded_socket(socket)
            end
          end

          [-1, {}, []]
        rescue StandardError => e
          [500, { "content-type" => "text/plain" }, ["Ruflet Rails protocol error: #{e.message}"]]
        end

        private

        def websocket_upgrade_request?(env)
          return false unless env["REQUEST_METHOD"] == "GET"

          upgrade = env["HTTP_UPGRADE"].to_s.downcase
          connection = env["HTTP_CONNECTION"].to_s.downcase
          key = env["HTTP_SEC_WEBSOCKET_KEY"].to_s

          upgrade == "websocket" && connection.include?("upgrade") && !key.empty?
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
      end
    end
  end
end
