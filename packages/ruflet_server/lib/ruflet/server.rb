# frozen_string_literal: true

require "digest/sha1"
require "socket"
require "thread"

require "ruflet_protocol"
require "ruflet_ui"

module Ruflet
  class Server
    attr_reader :port
    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    class WireCodec
      class << self
        def pack(value)
          case value
          when NilClass
            "\xc0".b
          when TrueClass
            "\xc3".b
          when FalseClass
            "\xc2".b
          when Integer
            pack_integer(value)
          when Float
            "\xcb".b + [value].pack("G")
          when String
            pack_string(value)
          when Symbol
            pack_string(value.to_s)
          when Array
            pack_array(value)
          when Hash
            pack_map(value)
          else
            pack_string(value.to_s)
          end
        end

        def unpack(bytes)
          reader = ByteReader.new(bytes)
          read_value(reader)
        end

    private

        def pack_integer(value)
          if value >= 0
            return [value].pack("C") if value <= 0x7f
            return "\xcc".b + [value].pack("C") if value <= 0xff
            return "\xcd".b + [value].pack("n") if value <= 0xffff
            return "\xce".b + [value].pack("N") if value <= 0xffff_ffff

            "\xcf".b + [value].pack("Q>")
          else
            return [value & 0xff].pack("C") if value >= -32
            return "\xd0".b + [value].pack("c") if value >= -128
            return "\xd1".b + [value].pack("s>") if value >= -32_768
            return "\xd2".b + [value].pack("l>") if value >= -2_147_483_648

            "\xd3".b + [value].pack("q>")
          end
        end

        def pack_string(value)
          str = value.to_s.dup.force_encoding("UTF-8")
          bytes = str.b
          len = bytes.bytesize

          if len <= 31
            [0xA0 | len].pack("C") + bytes
          elsif len <= 0xff
            "\xd9".b + [len].pack("C") + bytes
          elsif len <= 0xffff
            "\xda".b + [len].pack("n") + bytes
          else
            "\xdb".b + [len].pack("N") + bytes
          end
        end

        def pack_array(value)
          len = value.length
          head =
            if len <= 15
              [0x90 | len].pack("C")
            elsif len <= 0xffff
              "\xdc".b + [len].pack("n")
            else
              "\xdd".b + [len].pack("N")
            end

          body = +"".b
          value.each { |item| body << pack(item) }
          head + body
        end

        def pack_map(value)
          pairs = value.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
          len = pairs.length
          head =
            if len <= 15
              [0x80 | len].pack("C")
            elsif len <= 0xffff
              "\xde".b + [len].pack("n")
            else
              "\xdf".b + [len].pack("N")
            end

          body = +"".b
          pairs.each do |k, v|
            body << pack(k)
            body << pack(v)
          end
          head + body
        end

        def read_value(reader)
          marker = reader.read_u8

          return marker if marker <= 0x7f
          return marker - 256 if marker >= 0xe0

          case marker
          when 0xc0 then nil
          when 0xc2 then false
          when 0xc3 then true
          when 0xcc then reader.read_u8
          when 0xcd then reader.read_u16
          when 0xce then reader.read_u32
          when 0xcf then reader.read_u64
          when 0xd0 then reader.read_i8
          when 0xd1 then reader.read_i16
          when 0xd2 then reader.read_i32
          when 0xd3 then reader.read_i64
          when 0xca then reader.read_f32
          when 0xcb then reader.read_f64
          when 0xd9 then reader.read_string(reader.read_u8)
          when 0xda then reader.read_string(reader.read_u16)
          when 0xdb then reader.read_string(reader.read_u32)
          when 0xdc then read_array(reader, reader.read_u16)
          when 0xdd then read_array(reader, reader.read_u32)
          when 0xde then read_map(reader, reader.read_u16)
          when 0xdf then read_map(reader, reader.read_u32)
          else
            if (marker & 0xf0) == 0x90
              read_array(reader, marker & 0x0f)
            elsif (marker & 0xf0) == 0x80
              read_map(reader, marker & 0x0f)
            elsif (marker & 0xe0) == 0xa0
              reader.read_string(marker & 0x1f)
            else
              raise "Unsupported MessagePack marker: 0x#{marker.to_s(16)}"
            end
          end
        end

        def read_array(reader, size)
          Array.new(size) { read_value(reader) }
        end

        def read_map(reader, size)
          out = {}
          size.times do
            key = read_value(reader)
            out[key.to_s] = read_value(reader)
          end
          out
        end
      end

      class ByteReader
        def initialize(bytes)
          @data = bytes.to_s.b
          @offset = 0
        end

        def read_u8
          value = @data.getbyte(@offset)
          raise "Unexpected EOF" if value.nil?

          @offset += 1
          value
        end

        def read_exact(size)
          chunk = @data.byteslice(@offset, size)
          raise "Unexpected EOF" if chunk.nil? || chunk.bytesize != size

          @offset += size
          chunk
        end

        def read_u16
          read_exact(2).unpack1("n")
        end

        def read_u32
          read_exact(4).unpack1("N")
        end

        def read_u64
          read_exact(8).unpack1("Q>")
        end

        def read_i8
          read_exact(1).unpack1("c")
        end

        def read_i16
          read_exact(2).unpack1("s>")
        end

        def read_i32
          read_exact(4).unpack1("l>")
        end

        def read_i64
          read_exact(8).unpack1("q>")
        end

        def read_f32
          read_exact(4).unpack1("g")
        end

        def read_f64
          read_exact(8).unpack1("G")
        end

        def read_string(size)
          read_exact(size).force_encoding("UTF-8")
        end
      end
    end

    class WebSocketConnection
      def initialize(socket)
        @socket = socket
        @write_mutex = Mutex.new
      end

      def session_key
        @socket.object_id
      end

      def closed?
        @socket.closed?
      rescue IOError
        true
      end

      def send_binary(payload)
        send_frame(0x2, payload.to_s.b)
      end

      def send_text(payload)
        send_frame(0x1, payload.to_s.b)
      end

      def read_message
        frame = read_frame
        return nil if frame.nil?

        opcode = frame[:opcode]
        payload = frame[:payload]

        case opcode
        when 0x8
          close
          nil
        when 0x9
          send_frame(0xA, payload)
          read_message
        when 0xA
          read_message
        when 0x1, 0x2
          payload
        else
          read_message
        end
      end

      def close
        return if closed?

        begin
          @socket.close
        rescue IOError
          nil
        end
      end

      private

      def read_frame
  header = read_exact(2)
  return nil if header.nil?

  b1 = header.getbyte(0)
  b2 = header.getbyte(1)

  masked = (b2 & 0x80) != 0
  payload_len = b2 & 0x7f

  payload_len = read_exact(2).unpack1("n") if payload_len == 126
  payload_len = read_exact(8).unpack1("Q>") if payload_len == 127

  masking_key = masked ? read_exact(4) : nil
  payload = payload_len.zero? ? "".b : read_exact(payload_len)
  return nil if payload.nil?

  payload = unmask(payload, masking_key) if masked

  { opcode: b1 & 0x0f, payload: payload }
end

def send_frame(opcode, payload)
  bytes = payload.to_s.b
  len = bytes.bytesize
  header = [0x80 | (opcode & 0x0f)].pack("C")

  header <<
    if len <= 125
      [len].pack("C")
    elsif len <= 0xffff
      [126].pack("C") + [len].pack("n")
    else
      [127].pack("C") + [len].pack("Q>")
    end

  @write_mutex.synchronize do
    @socket.write(header)
    @socket.write(bytes) unless bytes.empty?
  end
end

  def unmask(payload, mask)
    out = +""
    out.force_encoding(Encoding::BINARY)
    payload.bytes.each_with_index do |byte, idx|
      out << (byte ^ mask.getbyte(idx % 4))
    end
    out
  end

  def read_exact(length)
    chunk = +""
    chunk.force_encoding(Encoding::BINARY)

    while chunk.bytesize < length
      part = @socket.read(length - chunk.bytesize)
      return nil if part.nil? || part.empty?

      chunk << part
    end

    chunk
  end
end

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
      previous_int = Signal.trap("INT") do
        stop
        Thread.main.raise(Interrupt)
      rescue StandardError
        nil
      end
      previous_term = Signal.trap("TERM") do
        stop
        Thread.main.raise(Interrupt)
      rescue StandardError
        nil
      end

      bind_server_socket!
      @running = true

      warn "Ruflet server listening on ws://#{@host}:#{@port}/ws" unless ENV["RUFLET_SUPPRESS_SERVER_BANNER"] == "1"

      while @running
        begin
          accepted = @server_socket.accept
          socket = accepted.is_a?(Array) ? accepted.first : accepted
          Thread.new(socket) do |client|
            Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
            handle_socket(client)
          end
        rescue IOError, Errno::EBADF
          break
        rescue StandardError => e
          warn "accept error: #{e.class}: #{e.message}"
          warn e.backtrace.join("\n") if e.backtrace
        end
      end
    rescue Interrupt
      nil
    ensure
      stop
      Signal.trap("INT", previous_int) if previous_int
      Signal.trap("TERM", previous_term) if previous_term
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

    def handle_socket(socket)
      ws = nil
      begin
        path, headers = read_http_upgrade_request(socket)
        return unless websocket_upgrade_request?(path, headers)

        send_handshake_response(socket, headers["sec-websocket-key"])
        ws = WebSocketConnection.new(socket)
        register_connection(ws)

        while (raw = ws.read_message)
          handle_message(ws, raw)
        end
      rescue StandardError => e
        warn "server error: #{e.class}: #{e.message}"
        warn e.backtrace.join("\n") if e.backtrace
        send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") }) if ws
      ensure
        remove_session(ws)
        unregister_connection(ws)
        ws&.close
      end
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
      parsed = normalize_incoming(WireCodec.unpack(raw.to_s.b))

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
        sender: lambda { |action, msg_payload|
          send_message(ws, action, msg_payload)
        }
      )

      @sessions_mutex.synchronize do
        @sessions[ws.session_key] = { page: page }
      end

      send_message(ws, Protocol::ACTIONS[:register_client], Protocol.register_response(session_id: session_id))
      @app_block&.call(page)
    end

    def on_control_event(ws, payload)
      session = @sessions_mutex.synchronize { @sessions[ws.session_key] }
      return unless session

      if payload.key?("target")
        session[:page].dispatch_event(
          target: payload["target"],
          name: payload["name"],
          data: payload["data"]
        )
      else
        session[:page].dispatch_event(
          target: payload["eventTarget"],
          name: payload["eventName"],
          data: payload["eventData"]
        )
      end
    end

    def on_update_control(ws, payload)
      session = @sessions_mutex.synchronize { @sessions[ws.session_key] }
      return unless session

      control_id = payload["id"] || payload["target"] || payload["eventTarget"]
      props = payload["props"] || {}
      return if control_id.nil? || !props.is_a?(Hash)

      session[:page].apply_client_update(control_id, props)
    end

    def send_message(ws, action, payload)
      packet = Protocol.pack_message(action: action, payload: normalize_for_wire(payload))
      ws.send_binary(WireCodec.pack(packet))
    rescue StandardError => e
      warn "send error: #{e.class}: #{e.message}"
    end

    def normalize_for_wire(value)
      case value
      when String, Integer, Float, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Array
        value.map { |v| normalize_for_wire(v) }
      when Hash
        value.each_with_object({}) do |(k, v), out|
          out[k.to_s] = normalize_for_wire(v)
        end
      else
        value.to_s
      end
    end

    def pseudo_uuid
      # Lightweight UUID-like ID without SecureRandom dependency.
      time_part = (Time.now.to_f * 1_000_000).to_i
      rand_part = rand(1 << 64)
      hex = format("%016x%016x", time_part, rand_part)
      "#{hex[0, 8]}-#{hex[8, 4]}-4#{hex[13, 3]}-a#{hex[17, 3]}-#{hex[20, 12]}"
    end
  end
end
