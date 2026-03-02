# frozen_string_literal: true

module RufletProd
  class Server
    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    attr_reader :port

    def initialize(host: "0.0.0.0", port: 8550, manifest: nil, &app_block)
      @host = host
      @port = port
      @app_block = app_block
      @manifest = manifest
      @sessions = {}
      @running = false
      @server_socket = nil
    end

    def start
      bind_server_socket!
      @running = true
      print_server_banner

      while @running
        check_stop_signal!
        socket = accept_client_socket
        break unless socket

        handle_socket(socket)
      end
    rescue Interrupt
      nil
    ensure
      stop
    end

    def stop
      @running = false

      begin
        @server_socket&.close
      rescue IOError
        nil
      end
      @server_socket = nil
    end

    private

    def bind_server_socket!
      requested = @port.to_i
      @server_socket = TCPServer.new(@host, requested)
      @port = requested
    rescue Errno::EADDRINUSE
      raise Errno::EADDRINUSE, "RufletProd failed to bind #{@host}:#{requested}; port is in use"
    end

    def print_server_banner
      return if ENV["RUFLET_SUPPRESS_SERVER_BANNER"] == "1"

      warn "RufletProd server listening on ws://#{@host}:#{@port}/ws"
    end

    def accept_client_socket
      accepted = @server_socket.accept
      accepted.is_a?(Array) ? accepted.first : accepted
    rescue IOError, Errno::EBADF
      nil
    end

    def check_stop_signal!
      stop_file = ENV["RUFLET_PROD_STOP_FILE"].to_s
      return if stop_file.empty?

      @running = false if File.exist?(stop_file)
    end

    def handle_socket(socket)
      ws = nil
      begin
        path, headers = read_http_upgrade_request(socket)
        return unless websocket_upgrade_request?(path, headers)

        send_handshake_response(socket, headers["sec-websocket-key"])
        ws = RufletProd::WebSocketConnection.new(socket)
        run_connection(ws)
      rescue StandardError => e
        send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s }) if ws
      ensure
        close_connection(ws)
        begin
          socket.close unless socket.closed?
        rescue StandardError
          nil
        end
      end
    end

    def run_connection(ws)
      while (raw = ws.read_message)
        handle_message(ws, raw)
      end
    rescue StandardError => e
      send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s })
    ensure
      close_connection(ws)
    end

    def close_connection(ws)
      return unless ws

      @sessions.delete(ws.session_key)
      ws.close
    rescue StandardError
      nil
    end

    def read_http_upgrade_request(socket)
      request_line = socket.gets("\r\n")
      raise "Invalid HTTP request" if request_line.nil?

      method, path, = request_line.strip.split(" ", 3)
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
      accept = [sha1_digest("#{key}#{WEBSOCKET_GUID}")].pack("m0")

      socket.write("HTTP/1.1 101 Switching Protocols\r\n")
      socket.write("Upgrade: websocket\r\n")
      socket.write("Connection: Upgrade\r\n")
      socket.write("Sec-WebSocket-Accept: #{accept}\r\n")
      socket.write("\r\n")
    end

    def handle_message(ws, raw)
      action, payload = decode_incoming(raw)
      payload ||= {}

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
      parsed = normalize_incoming(RufletProd::WireCodec.unpack(raw.to_s))

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
        out = value.dup
        out.force_encoding("UTF-8") if out.respond_to?(:force_encoding)
        out
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

      unless @manifest
        send_message(ws, Protocol::ACTIONS[:session_crashed], {
          "message" => "RufletProd runtime requires a prebuilt manifest."
        })
        return
      end

      initial_response = [
        Protocol::ACTIONS[:register_client],
        {
          "session_id" => session_id,
          "page_patch" => {},
          "error" => nil
        }
      ]
      ws.send_binary(RufletProd::WireCodec.pack(initial_response))
      replay_manifest(ws)
    end

    def on_control_event(ws, payload)
      return if @manifest

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
      return if @manifest

      update = Protocol.normalize_update_control_payload(payload)
      page = fetch_page(ws)
      return if update["id"].nil?

      page.apply_client_update(update["id"], update["props"] || {})
    end

    def fetch_page(ws)
      page = @sessions[ws.session_key]
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
      return unless ws

      message = [action, payload]
      ws.send_binary(RufletProd::WireCodec.pack(message))
    rescue StandardError
      nil
    end

    def pseudo_uuid
      now = (Time.now.to_f * 1_000_000).to_i
      rnd = rand(0..0xffff_ffff)
      "%08x-%04x-%04x-%04x-%012x" % [
        rnd,
        now & 0xffff,
        (now >> 16) & 0xffff,
        (now >> 32) & 0xffff,
        (now >> 48) & 0xffff_ffff_ffff
      ]
    end

    # Minimal SHA-1 implementation to avoid depending on digest stdlib in mruby.
    def sha1_digest(data)
      bytes = data.to_s
      bit_len = bytes.bytesize * 8
      bytes += "\x80"
      bytes += "\x00" while (bytes.bytesize % 64) != 56

      hi = (bit_len >> 32) & 0xffffffff
      lo = bit_len & 0xffffffff
      bytes += [hi, lo].pack("N2")

      h0 = 0x67452301
      h1 = 0xEFCDAB89
      h2 = 0x98BADCFE
      h3 = 0x10325476
      h4 = 0xC3D2E1F0

      bytes.bytes.each_slice(64) do |chunk|
        w = Array.new(80, 0)
        16.times do |i|
          j = i * 4
          w[i] = ((chunk[j] << 24) | (chunk[j + 1] << 16) | (chunk[j + 2] << 8) | chunk[j + 3]) & 0xffffffff
        end
        (16..79).each do |i|
          v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
          w[i] = ((v << 1) | (v >> 31)) & 0xffffffff
        end

        a = h0
        b = h1
        c = h2
        d = h3
        e = h4

        80.times do |i|
          if i < 20
            f = ((b & c) | ((~b) & d)) & 0xffffffff
            k = 0x5A827999
          elsif i < 40
            f = (b ^ c ^ d) & 0xffffffff
            k = 0x6ED9EBA1
          elsif i < 60
            f = ((b & c) | (b & d) | (c & d)) & 0xffffffff
            k = 0x8F1BBCDC
          else
            f = (b ^ c ^ d) & 0xffffffff
            k = 0xCA62C1D6
          end

          temp = ((((a << 5) | (a >> 27)) & 0xffffffff) + f + e + k + w[i]) & 0xffffffff
          e = d
          d = c
          c = ((b << 30) | (b >> 2)) & 0xffffffff
          b = a
          a = temp
        end

        h0 = (h0 + a) & 0xffffffff
        h1 = (h1 + b) & 0xffffffff
        h2 = (h2 + c) & 0xffffffff
        h3 = (h3 + d) & 0xffffffff
        h4 = (h4 + e) & 0xffffffff
      end

      [h0, h1, h2, h3, h4].pack("N5")
    end

    def replay_manifest(ws)
      return unless @manifest.is_a?(Hash)

      manifest_messages = @manifest["messages"]
      return unless manifest_messages.is_a?(Array)

      manifest_messages.each do |message|
        action = message["action"] || message[:action]
        payload = message["payload"] || message[:payload]
        send_message(ws, action, payload || {})
      end
    end
  end
end
