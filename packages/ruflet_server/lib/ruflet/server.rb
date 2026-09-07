# frozen_string_literal: true

require "digest/sha1"
require "socket"
require "thread"

require "ruflet_core"
require_relative "server/in_process_connection"
require_relative "server/wire_codec"
require_relative "server/web_socket_connection"

module Ruflet
  class Server
    attr_reader :port

    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    TASK_IO_POLL_INTERVAL = 0.01

    def initialize(host: "0.0.0.0", port: 8550, in_process_bridge: nil, &app_block)
      @host = host
      @port = port
      @in_process_bridge = in_process_bridge
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
      if Object.const_defined?(:Task) && Task.current.name == "main"
        server = self
        task = Task.new(name: "ruflet-server") { server.start }
        Task.run
        return task
      end

      previous_signals = trap_stop_signals
      if in_process_transport_requested?
        start_in_process_transport
      else
        bind_server_socket!
        @running = true
        print_server_banner
        accept_loop
      end
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
      attempts = ENV["RUFLET_STRICT_PORT"] == "1" ? 1 : max_attempts

      attempts.times do
        begin
          @server_socket = TCPServer.new(@host, candidate)
          @port = @server_socket.addr[1]
          publish_runtime_port
          if requested > 0 && @port != requested && ENV["RUFLET_SUPPRESS_SERVER_BANNER"] != "1"
            warn "Requested port #{requested} is busy; bound to #{@port}"
          end
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

    def publish_runtime_port
      path = ENV["RUFLET_RUNTIME_PORT_FILE"].to_s
      return if path.empty?

      File.open(path, "w") { |file| file.write(@port.to_s) }
    rescue StandardError => error
      warn "Unable to publish Ruflet runtime port: #{error.message}"
    end

    def reload_app!
      snapshots = @sessions_mutex.synchronize { @sessions.to_a }

      snapshots.each do |session_key, current_page|
        ws = @connections_mutex.synchronize { @connections[session_key] }
        next unless ws

        # Open dialogs, sheets, and snack bars are Navigator routes on the
        # client; replacing the control tree does not pop them. Close them
        # first, otherwise a reload while an overlay is open leaves it on
        # screen wired to control ids the reloaded page cannot resolve.
        begin
          nil while current_page.respond_to?(:close_dialog) && current_page.close_dialog
        rescue StandardError
          nil
        end

        if current_page.respond_to?(:reset_for_reload!)
          # Re-render on the live page. The client's overlay/service/dialogs
          # containers stay mounted; a recreated Page would re-send them,
          # replacing their client-side instances and detaching them — after
          # which dialog and service patches are silently ignored.
          current_page.reset_for_reload!
          @app_block.call(current_page)
          # Clear page-level chrome the reloaded block dropped and flush the
          # overlay (appbar/drawer/FAB live in the view and rebuild wholesale;
          # page props and the mounted overlay need explicit updates).
          current_page.finalize_reload! if current_page.respond_to?(:finalize_reload!)
          # Keeps route-driven apps on their current route: replays the
          # route_change event when the block did not route itself.
          current_page.replay_route_after_reload! if current_page.respond_to?(:replay_route_after_reload!)
          current_page.update
        else
          # Older ruflet_core without reset_for_reload!: fall back to a fresh
          # page (loses client-side container bindings until reconnect).
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
        end
      rescue StandardError => e
        warn "reload error: #{e.class}: #{e.message}"
      end
    end

    private

    def in_process_transport_requested?
      ENV["RUFLET_RUNTIME_TRANSPORT"] == "in_process"
    end

    def start_in_process_transport
      connection = Ruflet::InProcessConnection.new(bridge: @in_process_bridge)
      @running = true
      run_connection(connection)
    end

    def trap_stop_signals
      {
        "INT" => trap_signal("INT"),
        "TERM" => trap_signal("TERM")
      }
    end

    def trap_signal(signal_name)
      Signal.trap(signal_name) do
        # Trap context restricts Mutex use, so calling stop here raises
        # ThreadError and the signal is silently swallowed. Only unwind the
        # main thread; start's ensure performs the actual stop outside the
        # trap context.
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
      accepted = task_scheduler? ? @server_socket.accept_nonblock : @server_socket.accept
      accepted.is_a?(Array) ? accepted.first : accepted
    rescue IOError, Errno::EBADF
      nil
    rescue StandardError => e
      return nil unless @running && @server_socket

      if task_scheduler? && would_block_error?(e)
        sleep TASK_IO_POLL_INTERVAL
        Thread.pass if Thread.respond_to?(:cooperative?)
        retry
      end

      warn "accept error: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n") if e.backtrace
      nil
    end

    def task_scheduler?
      Object.const_defined?(:Task) || (Thread.respond_to?(:cooperative?) && Thread.cooperative?)
    end

    def would_block_error?(error)
      %w[Errno::EAGAIN Errno::EWOULDBLOCK IO::EAGAINWaitReadable IO::WaitReadable].include?(error.class.to_s)
    end

    def start_client_thread(socket)
      thread = Thread.new(socket) do |client|
        Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
        handle_socket(client)
      end
      Thread.pass if task_scheduler?
      thread
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

    def run_connection(ws)
      register_connection(ws)

      while (raw = ws.read_message)
        handle_message(ws, raw)
      end
    rescue StandardError => e
      return if disconnect_error?(e)

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
      request_line = read_http_line(socket)
      return [nil, {}] if request_line.nil?
      return [nil, {}] unless request_line.include?(" ")

      method, path, _version = request_line.strip.split(" ", 3)
      return [nil, {}] unless method == "GET"
      return [nil, {}] if path.to_s.empty?

      headers = {}
      loop do
        line = read_http_line(socket)
        break if line.nil? || line == "\r\n"

        key, value = line.split(":", 2)
        next if key.nil? || value.nil?

        headers[key.strip.downcase] = value.strip
      end

      [path, headers]
    ensure
      @http_read_buffers&.delete(socket.object_id) if task_scheduler?
    end

    def read_http_line(socket)
      return socket.gets("\r\n") unless task_scheduler? && socket.respond_to?(:recv_nonblock)

      @http_read_buffers ||= {}
      buffer = (@http_read_buffers[socket.object_id] ||= +"")
      loop do
        newline = buffer.index("\r\n")
        return buffer.slice!(0, newline + 2) if newline

        begin
          part = socket.recv_nonblock(4096)
          return nil if part.nil? || part.empty?

          buffer << part
        rescue StandardError => error
          raise unless would_block_error?(error)

          sleep TASK_IO_POLL_INTERVAL
        end
      end
    end

    def websocket_upgrade_request?(path, headers)
      return false unless path == "/ws"
      return false unless headers["upgrade"]&.downcase == "websocket"
      return false unless headers["connection"]&.downcase&.include?("upgrade")
      return false if headers["sec-websocket-key"].to_s.empty?

      true
    end

    def handle_http_request(socket, path)
      request_path = path.to_s.split("?", 2).first.to_s
      return if serve_web_client(socket, request_path)

      case request_path
      when "/health"
        write_http_response(socket, 200, "text/plain", "ok")
      when "/"
        write_http_response(socket, 200, "text/plain", "ruflet server")
      else
        if request_path.start_with?("/assets/")
          serve_asset(socket, request_path)
        else
          write_http_response(socket, 404, "text/plain", "not found")
        end
      end
    rescue StandardError => e
      warn "http error: #{e.class}: #{e.message}"
      write_http_response(socket, 500, "text/plain", "server error")
    end

    # The Flutter web client is served from this same port so that it loads and
    # opens its websocket on one origin. Without that the client cannot reach
    # /ws at all.
    def web_client_root
      # Memoized with a separate flag rather than defined?(@web_client_root):
      # the embedded mruby VM has no defined? keyword, so it parses as a method
      # call and every request raises NoMethodError. The resolved value is
      # legitimately nil when no web client is configured, so nil cannot double
      # as "not resolved yet".
      return @web_client_root if @web_client_root_resolved

      configured = ENV["RUFLET_WEB_CLIENT_DIR"].to_s.strip
      @web_client_root =
        if configured.empty? || !File.directory?(configured)
          nil
        else
          File.expand_path(configured)
        end
      @web_client_root_resolved = true
      @web_client_root
    end

    def serve_web_client(socket, request_path)
      root = web_client_root
      return false unless root

      relative = request_path
      relative = "/index.html" if relative.empty? || relative == "/"
      candidate = File.expand_path(File.join(root, relative))
      # Never serve outside the client bundle.
      return false unless candidate == root || candidate.start_with?("#{root}#{File::SEPARATOR}")
      return false unless File.file?(candidate)

      content = read_binary_file(candidate)
      write_http_response(socket, 200, content_type_for(candidate), content, binary: true)
      true
    end

    def serve_asset(socket, path)
      asset_path = resolve_asset_path(path)
      unless asset_path
        write_http_response(socket, 404, "text/plain", "not found")
        return
      end

      content = read_binary_file(asset_path)
      write_http_response(socket, 200, content_type_for(asset_path), content, binary: true)
    end

    def read_binary_file(path)
      File.open(path, "rb") { |file| file.read }
    end

    def resolve_asset_path(path)
      root = assets_root
      return nil unless root

      root = File.expand_path(root)
      prefix = "/assets/"
      return nil unless path.start_with?(prefix)

      relative = path[prefix.length..-1].to_s
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
      when ".html", ".htm"
        "text/html; charset=utf-8"
      when ".js", ".mjs"
        "text/javascript; charset=utf-8"
      when ".css"
        "text/css; charset=utf-8"
      when ".json", ".map"
        "application/json; charset=utf-8"
      when ".wasm"
        "application/wasm"
      when ".ttf"
        "font/ttf"
      when ".otf"
        "font/otf"
      when ".woff"
        "font/woff"
      when ".woff2"
        "font/woff2"
      when ".ico"
        "image/x-icon"
      when ".txt", ".symbols"
        "text/plain; charset=utf-8"
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

      warn "incoming action=#{action.inspect}" if ENV["RUFLET_DEBUG"] == "1"

      case action
      when Protocol::ACTIONS[:register_client], Protocol::ACTIONS[:register_web_client]
        on_register_client(ws, payload)
      when Protocol::ACTIONS[:control_event], Protocol::ACTIONS[:page_event_from_web]
        on_control_event(ws, payload)
      when Protocol::ACTIONS[:update_control], Protocol::ACTIONS[:update_control_props]
        on_update_control(ws, payload)
      when Protocol::ACTIONS[:invoke_control_method]
        on_invoke_control_method(ws, payload)
      when Protocol::ACTIONS[:python_output]
        nil
      else
        raise "Unknown action: #{action.inspect}"
      end
    rescue StandardError => e
      # A per-message handler error (e.g. an event callback that renders a
      # control the runtime does not implement) must not tear down the whole
      # WebSocket connection — that would disconnect the client on every
      # navigation. Log it and keep the session alive.
      warn "[embedded server] handle_message error: #{e.class}: #{e.message}"
      warn e.backtrace.join("\n") if e.backtrace && ENV["RUFLET_DEBUG"] == "1"
      report_runtime_error(e, "handle_message")
    end

    def report_runtime_error(error, context)
      path = ENV["RUFLET_RUNTIME_ERROR_FILE"].to_s
      return if path.empty?

      lines = ["#{context}: #{error.class}: #{error.message}"]
      lines.concat(error.backtrace) if error.backtrace
      File.open(path, "w") { |file| file.write(lines.join("\n")) }
    rescue StandardError => report_error
      warn "runtime error reporting failed: #{report_error.class}: #{report_error.message}"
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

      # Run the app block BEFORE responding and ship the complete state in the
      # register response (page_patch), like Flet. The client merges that map
      # by control id, keeping existing instances alive — required for
      # reconnecting clients (backend restarts) whose control store persists.
      # Incremental op patches sent during the block are superseded by the
      # full state and dropped; everything else is flushed afterwards.
      registered = false
      buffered = []
      page = Page.new(
        session_id: session_id,
        client_details: normalized,
        sender: lambda do |action, msg_payload|
          if registered
            send_message(ws, action, msg_payload)
          else
            buffered << [action, msg_payload]
          end
        end
      )

      page.title = "Ruflet App"

      @sessions_mutex.synchronize do
        @sessions[ws.session_key] = page
      end

      @app_block.call(page)

      page_patch = page.respond_to?(:register_page_patch) ? page.register_page_patch : {}
      response = begin
        Protocol.register_response(session_id: session_id, page_patch: page_patch)
      rescue ArgumentError
        # Older ruflet_core without the page_patch parameter.
        page_patch = {}
        Protocol.register_response(session_id: session_id)
      end
      initial_response = [
        Protocol::ACTIONS[:register_client],
        response
      ]
      ws.send_binary(Ruflet::WireCodec.pack(initial_response))
      registered = true

      buffered.each do |action, msg_payload|
        next if action == Protocol::ACTIONS[:patch_control]

        send_message(ws, action, msg_payload)
      end
      page.update if page_patch.empty?
    rescue StandardError => e
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message })
      raise e
    end

    def on_invoke_control_method(ws, payload)
      page = fetch_page(ws)
      page.handle_invoke_method_result(payload)
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
      return if ws.nil? || ws.closed?

      message = [action, payload]
      packed = Ruflet::WireCodec.pack(message)
      ws.send_binary(packed)
    rescue StandardError => e
      unless disconnect_error?(e)
        warn "send error: #{e.class}: #{e.message}"
      end
      remove_session(ws)
      unregister_connection(ws)
      ws&.close
    end

    def disconnect_error?(error)
      return true if error.is_a?(IOError)
      return true if error.is_a?(Errno::EPIPE)
      return true if error.is_a?(Errno::ECONNRESET)
      return true if error.is_a?(Errno::ECONNABORTED)
      return true if error.is_a?(Errno::ENOTCONN)
      return true if error.is_a?(Errno::ESHUTDOWN)
      return true if error.is_a?(Errno::EBADF)
      return true if error.is_a?(Errno::EINVAL)

      false
    end

    def pseudo_uuid
      rnd = (rand(0..0xffff) << 16) | rand(0..0xffff)
      "%08x-%04x-%04x-%04x-%012x" % [
        rnd,
        rand(0..0xffff),
        rand(0..0xffff),
        rand(0..0xffff),
        (rand(0..0xffff) << 32) | (rand(0..0xffff) << 16) | rand(0..0xffff)
      ]
    end
  end
end
