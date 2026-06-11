# frozen_string_literal: true

require "digest/sha1"
require "socket"
require "thread"

require "ruflet_core"
require_relative "server/wire_codec"
require_relative "server/web_socket_connection"
require_relative "server/connection_protocol"

module Ruflet
  # Standalone TCP transport for the Ruflet protocol. The protocol itself
  # lives in Ruflet::ConnectionProtocol and is shared with host-server
  # adapters (e.g. ruflet_rails runs it on the Rails server's own socket).
  class Server
    include ConnectionProtocol

    attr_reader :port

    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    def initialize(host: "0.0.0.0", port: 8550, &app_block)
      @host = host
      @port = port
      @app_block = app_block
      @sessions = {}
      @sessions_mutex = Mutex.new
      @connections = {}
      @connections_mutex = Mutex.new
      @running = false
      @server_socket = nil

      at_exit do
        begin
          stop
        rescue StandardError
          nil
        end
      end
    end

    def start
      previous_signals = trap_stop_signals
      bind_server_socket!
      @running = true
      print_server_banner
      accept_loop
    rescue Interrupt
      nil
    ensure
      stop
      restore_stop_signals(previous_signals)
    end

    def bind_server_socket!(max_attempts: 100)
      requested = @port.to_i
      candidate = requested
      attempts = ENV["RUFLET_STRICT_PORT"] == "1" ? 1 : max_attempts

      attempts.times do
        begin
          @server_socket = TCPServer.new(@host, candidate)
          @port = candidate
          if @port != requested && ENV["RUFLET_SUPPRESS_SERVER_BANNER"] != "1"
            warn "Requested port #{requested} is busy; bound to #{@port}"
          end
          publish_bound_port!
          return
        rescue Errno::EADDRINUSE
          candidate += 1
        end
      end

      raise Errno::EADDRINUSE, "Unable to bind port #{requested}" if attempts == 1

      raise Errno::EADDRINUSE, "Unable to bind starting at #{requested} after #{max_attempts} attempts"
    end

    def stop
      return unless @running || @server_socket

      @running = false
      remove_port_file!

      server = @server_socket
      @server_socket = nil
      begin
        server&.close
      rescue IOError
        nil
      end

      live_connections = @connections_mutex.synchronize { @connections.values.dup }
      live_connections.each do |conn|
        begin
          conn.close
        rescue StandardError
          nil
        end
      end
    end

    def reload_app!
      snapshots = @sessions_mutex.synchronize { @sessions.to_a }

      snapshots.each do |session_key, current_page|
        ws = @connections_mutex.synchronize { @connections[session_key] }
        next unless ws

        refreshed_page = Page.new(
          session_id: current_page.session_id,
          client_details: current_page.client_details,
          sender: lambda do |action, payload|
            send_message(ws, action, payload)
          end
        )
        refreshed_page.title = "Ruflet App"

        @sessions_mutex.synchronize do
          @sessions[session_key] = refreshed_page
        end

        @app_block.call(refreshed_page)
        refreshed_page.update
      rescue StandardError => e
        warn "reload error: #{e.class}: #{e.message}"
      end
    end

    private

    # Lets embedding hosts (e.g. the ruby_runtime Flutter plugins) discover
    # which port the server actually bound when the requested one was busy.
    def publish_bound_port!
      path = ENV["RUFLET_PORT_FILE"].to_s
      return if path.empty?

      begin
        File.write(path, @port.to_s)
      rescue StandardError
        nil
      end
    end

    def remove_port_file!
      path = ENV["RUFLET_PORT_FILE"].to_s
      return if path.empty?

      begin
        File.delete(path)
      rescue StandardError
        nil
      end
    end

    def trap_stop_signals
      {
        "INT" => trap_signal("INT"),
        "TERM" => trap_signal("TERM")
      }
    end

    def trap_signal(signal_name)
      Signal.trap(signal_name) do
        stop
        Thread.main.raise(Interrupt)
      rescue StandardError
        nil
      end
    end

    def restore_stop_signals(previous_signals)
      return unless previous_signals

      previous_signals.each do |signal_name, handler|
        Signal.trap(signal_name, handler) if handler
      end
    end

    def print_server_banner
      return if ENV["RUFLET_SUPPRESS_SERVER_BANNER"] == "1"

      warn "Ruflet server listening on ws://#{@host}:#{@port}/ws"
    end

    def accept_loop
      while @running
        socket = accept_client_socket
        break unless socket

        start_client_thread(socket)
      end
    end

    def accept_client_socket
      accepted = @server_socket.accept
      accepted.is_a?(Array) ? accepted.first : accepted
    rescue IOError, Errno::EBADF
      nil
    rescue StandardError => e
      return nil unless @running && @server_socket

      warn "accept error: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n") if e.backtrace
      nil
    end

    def start_client_thread(socket)
      Thread.new(socket) do |client|
        Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
        handle_socket(client)
      end
    end

    def handle_socket(socket)
      ws = nil
      begin
        path, headers = read_http_upgrade_request(socket)
        return if path.nil?

        if websocket_upgrade_request?(path, headers)
          send_handshake_response(socket, headers["sec-websocket-key"])
          ws = Ruflet::WebSocketConnection.new(socket)
          run_connection(ws)
        else
          handle_http_request(socket, path)
        end
      rescue StandardError => e
        return if disconnect_error?(e)

        warn "server error: #{e.class}: #{e.message}"
        warn e.backtrace.join("\n") if e.backtrace
        send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") }) if ws
      ensure
        close_connection(ws)
      end
    end

    def read_http_upgrade_request(socket)
      request_line = socket.gets("\r\n")
      return [nil, {}] if request_line.nil?
      return [nil, {}] unless request_line.include?(" ")

      method, path, _version = request_line.strip.split(" ", 3)
      return [nil, {}] unless method == "GET"
      return [nil, {}] if path.to_s.empty?

      headers = {}
      loop do
        line = socket.gets("\r\n")
        break if line.nil? || line == "\r\n"

        key, value = line.split(":", 2)
        next if key.nil? || value.nil?

        headers[key.strip.downcase] = value.strip
      end

      [path, headers]
    end

    def websocket_upgrade_request?(path, headers)
      return false unless path == "/ws"
      return false unless headers["upgrade"]&.downcase == "websocket"
      return false unless headers["connection"]&.downcase&.include?("upgrade")
      return false if headers["sec-websocket-key"].to_s.empty?

      true
    end

    def handle_http_request(socket, path)
      case path
      when "/health"
        write_http_response(socket, 200, "text/plain", "ok")
      when "/"
        write_http_response(socket, 200, "text/plain", "ruflet server")
      else
        if path.start_with?("/assets/")
          serve_asset(socket, path)
        else
          write_http_response(socket, 404, "text/plain", "not found")
        end
      end
    rescue StandardError => e
      warn "http error: #{e.class}: #{e.message}"
      write_http_response(socket, 500, "text/plain", "server error")
    end

    def serve_asset(socket, path)
      asset_path = resolve_asset_path(path)
      unless asset_path
        write_http_response(socket, 404, "text/plain", "not found")
        return
      end

      content = File.binread(asset_path)
      write_http_response(socket, 200, content_type_for(asset_path), content, binary: true)
    end

    def resolve_asset_path(path)
      root = assets_root
      return nil unless root

      root = File.expand_path(root)
      relative = path.sub(%r{\A/assets/}, "")
      full = File.expand_path(File.join(root, relative))
      return nil unless full.start_with?(root + File::SEPARATOR) || full == root
      return nil unless File.file?(full)

      full
    end

    def assets_root
      root = ENV["RUFLET_ASSETS_DIR"].to_s
      return root unless root.empty?

      default_root = File.join(Dir.pwd, "assets")
      File.directory?(default_root) ? default_root : nil
    end

    def content_type_for(path)
      case File.extname(path).downcase
      when ".png"
        "image/png"
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".gif"
        "image/gif"
      when ".webp"
        "image/webp"
      when ".svg"
        "image/svg+xml"
      else
        "application/octet-stream"
      end
    end

    def write_http_response(socket, status, content_type, body, binary: false)
      reason = {
        200 => "OK",
        404 => "Not Found",
        500 => "Internal Server Error"
      }[status] || "OK"

      body_str = binary ? body : body.to_s
      length = body_str.bytesize

      socket.write("HTTP/1.1 #{status} #{reason}\r\n")
      socket.write("Content-Type: #{content_type}\r\n")
      socket.write("Content-Length: #{length}\r\n")
      socket.write("Connection: close\r\n")
      socket.write("\r\n")
      socket.write(body_str)
    end

    def send_handshake_response(socket, key)
      accept = [Digest::SHA1.digest("#{key}#{WEBSOCKET_GUID}")].pack("m0")

      socket.write("HTTP/1.1 101 Switching Protocols\r\n")
      socket.write("Upgrade: websocket\r\n")
      socket.write("Connection: Upgrade\r\n")
      socket.write("Sec-WebSocket-Accept: #{accept}\r\n")
      socket.write("\r\n")
    end

    # ConnectionProtocol hooks: track live sockets so #stop can close them.
    def connection_opened(ws)
      return unless ws

      @connections_mutex.synchronize do
        @connections[ws.session_key] = ws
      end
    end

    def connection_closed(ws)
      return unless ws

      @connections_mutex.synchronize do
        @connections.delete(ws.session_key)
      end
    end

  end
end
