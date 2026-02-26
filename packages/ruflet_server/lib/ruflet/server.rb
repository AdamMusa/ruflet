# frozen_string_literal: true

require "digest/sha1"
require "socket"
require "thread"

require "ruflet"
require_relative "server/wire_codec"
require_relative "server/web_socket_connection"

module Ruflet
  class Server
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

    # For Rack-hosted mode: caller already performed the HTTP upgrade.
    def handle_upgraded_socket(io)
      ws = Ruflet::WebSocketConnection.new(io)
      run_connection(ws)
    end

    def bind_server_socket!(max_attempts: 100)
      requested = @port.to_i
      candidate = requested

      max_attempts.times do
        begin
          @server_socket = TCPServer.new(@host, candidate)
          @port = candidate
          warn "Requested port #{requested} is busy; bound to #{@port}" if @port != requested
          return
        rescue Errno::EADDRINUSE
          candidate += 1
        end
      end

      raise Errno::EADDRINUSE, "Unable to bind starting at #{requested} after #{max_attempts} attempts"
    end

    def stop
      return unless @running || @server_socket

      @running = false

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

    private

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
        return unless websocket_upgrade_request?(path, headers)

        send_handshake_response(socket, headers["sec-websocket-key"])
        ws = Ruflet::WebSocketConnection.new(socket)
        run_connection(ws)
      rescue StandardError => e
        warn "server error: #{e.class}: #{e.message}"
        warn e.backtrace.join("\n") if e.backtrace
        send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") }) if ws
      ensure
        close_connection(ws)
      end
    end

    def run_connection(ws)
      register_connection(ws)

      while (raw = ws.read_message)
        handle_message(ws, raw)
      end
    rescue StandardError => e
      warn "server error: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n") if e.backtrace
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") })
    ensure
      close_connection(ws)
    end

    def close_connection(ws)
      remove_session(ws)
      unregister_connection(ws)
      ws&.close
    end

    def read_http_upgrade_request(socket)
      request_line = socket.gets("\r\n")
      raise "Invalid HTTP request" if request_line.nil?

      method, path, _version = request_line.strip.split(" ", 3)
      raise "Unsupported HTTP method: #{method}" unless method == "GET"

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

    def send_handshake_response(socket, key)
      accept = [Digest::SHA1.digest("#{key}#{WEBSOCKET_GUID}")].pack("m0")

      socket.write("HTTP/1.1 101 Switching Protocols\r\n")
      socket.write("Upgrade: websocket\r\n")
      socket.write("Connection: Upgrade\r\n")
      socket.write("Sec-WebSocket-Accept: #{accept}\r\n")
      socket.write("\r\n")
    end

    def remove_session(ws)
      return unless ws

      @sessions_mutex.synchronize do
        @sessions.delete(ws.session_key)
      end
    end

    def register_connection(ws)
      return unless ws

      @connections_mutex.synchronize do
        @connections[ws.session_key] = ws
      end
    end

    def unregister_connection(ws)
      return unless ws

      @connections_mutex.synchronize do
        @connections.delete(ws.session_key)
      end
    end

    def handle_message(ws, raw)
      action, payload = decode_incoming(raw)
      payload ||= {}

      warn "incoming action=#{action.inspect}" if ENV["FLET_DEBUG"] == "1"

      case action
      when Protocol::ACTIONS[:register_client], Protocol::ACTIONS[:register_web_client]
        on_register_client(ws, payload)
      when Protocol::ACTIONS[:control_event], Protocol::ACTIONS[:page_event_from_web]
        on_control_event(ws, payload)
      when Protocol::ACTIONS[:update_control], Protocol::ACTIONS[:update_control_props]
        on_update_control(ws, payload)
      else
        raise "Unknown action: #{action.inspect}"
      end
    end

    def decode_incoming(raw)
      parsed = normalize_incoming(Ruflet::WireCodec.unpack(raw.to_s.b))

      if parsed.is_a?(Array) && parsed.length >= 2
        return [parsed[0], parsed[1]]
      end

      if parsed.is_a?(Hash)
        action = parsed["action"] || parsed[:action]
        payload = parsed["payload"] || parsed[:payload]
        return [action, payload] unless action.nil?

        if (parsed.key?("target") || parsed.key?(:target)) && (parsed.key?("name") || parsed.key?(:name))
          return [Protocol::ACTIONS[:control_event], parsed]
        end
      end

      raise "Unsupported payload format"
    end

    def normalize_incoming(value)
      case value
      when String
        value.dup.force_encoding("UTF-8")
      when Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Array
        value.map { |v| normalize_incoming(v) }
      when Hash
        value.each_with_object({}) do |(k, v), out|
          out[k.to_s] = normalize_incoming(v)
        end
      else
        value.to_s
      end
    end

    def on_register_client(ws, payload)
      normalized = Protocol.normalize_register_payload(payload)
      session_id = normalized["session_id"].to_s.empty? ? pseudo_uuid : normalized["session_id"]

      page = Page.new(
        session_id: session_id,
        client_details: normalized,
        sender: lambda do |action, msg_payload|
          send_message(ws, action, msg_payload)
        end
      )

      page.title = "Ruflet App"

      @sessions_mutex.synchronize do
        @sessions[ws.session_key] = page
      end

      initial_response = [
        Protocol::ACTIONS[:register_client],
        {
          "session_id" => session_id,
          "page_patch" => {},
          "error" => nil
        }
      ]
      ws.send_binary(Ruflet::WireCodec.pack(initial_response))

      @app_block.call(page)
      page.update
    rescue StandardError => e
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message })
      raise
    end

    def on_control_event(ws, payload)
      event = Protocol.normalize_control_event_payload(payload)
      page = fetch_page(ws)
      return if event["target"].nil? || event["name"].to_s.empty?

      page.dispatch_event(
        target: event["target"],
        name: event["name"],
        data: normalize_event_data(event["data"])
      )
    end

    def on_update_control(ws, payload)
      update = Protocol.normalize_update_control_payload(payload)
      page = fetch_page(ws)
      return if update["id"].nil?

      page.apply_client_update(update["id"], update["props"] || {})
    end

    def fetch_page(ws)
      page = @sessions_mutex.synchronize { @sessions[ws.session_key] }
      raise "Session not found" unless page

      page
    end

    def normalize_event_data(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), out| out[k.to_sym] = normalize_event_data(v) }
      when Array
        value.map { |entry| normalize_event_data(entry) }
      else
        value
      end
    end

    def send_message(ws, action, payload)
      message = [action, payload]
      ws.send_binary(Ruflet::WireCodec.pack(message))
    rescue StandardError => e
      warn "send error: #{e.class}: #{e.message}"
    end

    def pseudo_uuid
      now = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      rnd = rand(0..0xffff_ffff)
      "%08x-%04x-%04x-%04x-%012x" % [
        rnd,
        now & 0xffff,
        (now >> 16) & 0xffff,
        (now >> 32) & 0xffff,
        (now >> 48) & 0xffff_ffff_ffff
      ]
    end
  end
end
