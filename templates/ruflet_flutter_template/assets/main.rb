module RufletProd
  module Protocol
    ACTIONS = {
      register_client: 1,
      patch_control: 2,
      control_event: 3,
      update_control: 4,
      invoke_control_method: 5,
      session_crashed: 6,
      register_web_client: "registerWebClient",
      page_event_from_web: "pageEventFromWeb",
      update_control_props: "updateControlProps"
    }.freeze

    def self.normalize_register_payload(payload)
      page = payload["page"] || {}
      {
        "session_id" => payload["session_id"],
        "page_name" => payload["page_name"] || "",
        "route" => page["route"] || "/",
        "width" => page["width"],
        "height" => page["height"],
        "platform" => page["platform"],
        "platform_brightness" => page["platform_brightness"],
        "media" => page["media"] || {}
      }
    end
  end

  class WireCodec
    class << self
      def pack(value)
        case value
        when NilClass
          "\xc0"
        when TrueClass
          "\xc3"
        when FalseClass
          "\xc2"
        when Integer
          pack_integer(value)
        when Float
          "\xcb" + [value].pack("G")
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
          return "\xcc" + [value].pack("C") if value <= 0xff
          return "\xcd" + [value].pack("n") if value <= 0xffff
          return "\xce" + [value].pack("N") if value <= 0xffff_ffff
          "\xcf" + [value].pack("Q>")
        else
          return [value & 0xff].pack("C") if value >= -32
          return "\xd0" + [value].pack("c") if value >= -128
          return "\xd1" + [value].pack("s>") if value >= -32_768
          return "\xd2" + [value].pack("l>") if value >= -2_147_483_648
          "\xd3" + [value].pack("q>")
        end
      end

      def pack_string(value)
        str = value.to_s
        len = str.bytesize
        if len <= 31
          [0xA0 | len].pack("C") + str
        elsif len <= 0xff
          "\xd9" + [len].pack("C") + str
        elsif len <= 0xffff
          "\xda" + [len].pack("n") + str
        else
          "\xdb" + [len].pack("N") + str
        end
      end

      def pack_array(value)
        len = value.length
        head =
          if len <= 15
            [0x90 | len].pack("C")
          elsif len <= 0xffff
            "\xdc" + [len].pack("n")
          else
            "\xdd" + [len].pack("N")
          end

        body = ""
        value.each { |item| body += pack(item) }
        head + body
      end

      def pack_map(value)
        pairs = {}
        value.each { |k, v| pairs[k.to_s] = v }
        len = pairs.length
        head =
          if len <= 15
            [0x80 | len].pack("C")
          elsif len <= 0xffff
            "\xde" + [len].pack("n")
          else
            "\xdf" + [len].pack("N")
          end

        body = ""
        pairs.each do |k, v|
          body += pack(k)
          body += pack(v)
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
        out = []
        i = 0
        while i < size
          out << read_value(reader)
          i += 1
        end
        out
      end

      def read_map(reader, size)
        out = {}
        i = 0
        while i < size
          key = read_value(reader)
          out[key.to_s] = read_value(reader)
          i += 1
        end
        out
      end
    end

    class ByteReader
      def initialize(bytes)
        @data = bytes.to_s
        @offset = 0
      end

      def read_u8
        value = @data.getbyte(@offset)
        raise "Unexpected EOF" if value.nil?
        @offset += 1
        value
      end

      def read_exact(size)
        chunk = @data[@offset, size]
        raise "Unexpected EOF" if chunk.nil? || chunk.bytesize != size
        @offset += size
        chunk
      end

      def read_u16; read_exact(2).unpack("n").first; end
      def read_u32; read_exact(4).unpack("N").first; end
      def read_u64; read_exact(8).unpack("Q>").first; end
      def read_i8; read_exact(1).unpack("c").first; end
      def read_i16; read_exact(2).unpack("s>").first; end
      def read_i32; read_exact(4).unpack("l>").first; end
      def read_i64; read_exact(8).unpack("q>").first; end
      def read_f32; read_exact(4).unpack("g").first; end
      def read_f64; read_exact(8).unpack("G").first; end
      def read_string(size); read_exact(size); end
    end
  end

  class WebSocketConnection
    def initialize(socket)
      @socket = socket
    end

    def send_binary(payload)
      send_frame(0x2, payload.to_s)
    end

    def read_message
      frame = read_frame
      return nil if frame.nil?
      opcode = frame[:opcode]
      if opcode == 0x8
        close
        return nil
      end
      if opcode == 0x9
        send_frame(0xA, frame[:payload])
        return read_message
      end
      if opcode == 0xA
        return read_message
      end
      return frame[:payload] if opcode == 0x1 || opcode == 0x2
      read_message
    end

    def close
      @socket.close
    rescue StandardError
      nil
    end

    private

    def read_frame
      header = read_exact(2)
      return nil if header.nil?
      b1 = header.getbyte(0)
      b2 = header.getbyte(1)
      masked = (b2 & 0x80) != 0
      payload_len = b2 & 0x7f
      payload_len = read_exact(2).unpack("n").first if payload_len == 126
      payload_len = read_exact(8).unpack("Q>").first if payload_len == 127
      masking_key = masked ? read_exact(4) : nil
      payload = payload_len == 0 ? "" : read_exact(payload_len)
      return nil if payload.nil?
      payload = unmask(payload, masking_key) if masked
      { opcode: (b1 & 0x0f), payload: payload }
    end

    def send_frame(opcode, payload)
      bytes = payload.to_s
      len = bytes.bytesize
      header = [0x80 | (opcode & 0x0f)].pack("C")
      if len <= 125
        header += [len].pack("C")
      elsif len <= 0xffff
        header += [126].pack("C") + [len].pack("n")
      else
        header += [127].pack("C") + [len].pack("Q>")
      end
      @socket.write(header)
      @socket.write(bytes) unless bytes.empty?
    end

    def unmask(payload, mask)
      out = ""
      i = 0
      max = payload.bytesize
      while i < max
        out += [(payload.getbyte(i) ^ mask.getbyte(i % 4))].pack("C")
        i += 1
      end
      out
    end

    def read_exact(length)
      chunk = ""
      while chunk.bytesize < length
        part = @socket.read(length - chunk.bytesize)
        return nil if part.nil? || part.empty?
        chunk += part
      end
      chunk
    end
  end

  module JsonParser
    def self.parse(source)
      parser = Parser.new(source)
      value = parser.parse_value
      parser.skip_ws
      raise "Trailing JSON content" unless parser.eof?
      value
    end

    class Parser
      def initialize(source)
        @s = source.to_s
        @i = 0
      end

      def eof?
        @i >= @s.length
      end

      def skip_ws
        @i += 1 while !eof? && @s.getbyte(@i) <= 0x20
      end

      def parse_value
        skip_ws
        raise "Unexpected EOF" if eof?
        ch = @s.getbyte(@i)
        if ch == 0x7B
          parse_object
        elsif ch == 0x5B
          parse_array
        elsif ch == 0x22
          parse_string
        elsif ch == 0x74
          parse_true
        elsif ch == 0x66
          parse_false
        elsif ch == 0x6E
          parse_null
        else
          parse_number
        end
      end

      private

      def parse_object
        expect_byte(0x7B)
        skip_ws
        out = {}
        if peek_byte == 0x7D
          @i += 1
          return out
        end
        loop do
          key = parse_string
          skip_ws
          expect_byte(0x3A)
          out[key] = parse_value
          skip_ws
          break if consume_if(0x7D)
          expect_byte(0x2C)
        end
        out
      end

      def parse_array
        expect_byte(0x5B)
        skip_ws
        out = []
        if peek_byte == 0x5D
          @i += 1
          return out
        end
        loop do
          out << parse_value
          skip_ws
          break if consume_if(0x5D)
          expect_byte(0x2C)
        end
        out
      end

      def parse_string
        expect_byte(0x22)
        out = ""
        until eof?
          ch = @s.getbyte(@i)
          @i += 1
          if ch == 0x22
            return out
          elsif ch == 0x5C
            esc = @s.getbyte(@i)
            @i += 1
            if esc == 0x22
              out += "\""
            elsif esc == 0x5C
              out += "\\"
            elsif esc == 0x2F
              out += "/"
            elsif esc == 0x62
              out += "\b"
            elsif esc == 0x66
              out += "\f"
            elsif esc == 0x6E
              out += "\n"
            elsif esc == 0x72
              out += "\r"
            elsif esc == 0x74
              out += "\t"
            elsif esc == 0x75
              hex = @s[@i, 4]
              raise "Invalid unicode escape" unless valid_hex4?(hex)
              out += "\\u" + hex
              @i += 4
            else
              raise "Invalid escape sequence"
            end
          else
            out += @s[@i - 1, 1]
          end
        end
        raise "Unterminated string"
      end

      def parse_true; expect_literal("true"); true; end
      def parse_false; expect_literal("false"); false; end
      def parse_null; expect_literal("null"); nil; end

      def parse_number
        start = @i
        @i += 1 if peek_byte == 0x2D
        if peek_byte == 0x30
          @i += 1
        else
          raise "Invalid number" unless digit?(peek_byte)
          @i += 1 while digit?(peek_byte)
        end
        if peek_byte == 0x2E
          @i += 1
          raise "Invalid number" unless digit?(peek_byte)
          @i += 1 while digit?(peek_byte)
        end
        if peek_byte == 0x65 || peek_byte == 0x45
          @i += 1
          @i += 1 if peek_byte == 0x2B || peek_byte == 0x2D
          raise "Invalid number" unless digit?(peek_byte)
          @i += 1 while digit?(peek_byte)
        end
        token = @s[start...@i]
        if token.index(".") || token.index("e") || token.index("E")
          token.to_f
        else
          token.to_i
        end
      end

      def expect_literal(str)
        raise "Invalid token" unless @s[@i, str.length] == str
        @i += str.length
      end

      def expect_byte(byte)
        skip_ws
        raise "Unexpected EOF" if eof?
        raise "Unexpected token" unless @s.getbyte(@i) == byte
        @i += 1
      end

      def consume_if(byte)
        skip_ws
        return false if eof? || @s.getbyte(@i) != byte
        @i += 1
        true
      end

      def peek_byte
        eof? ? nil : @s.getbyte(@i)
      end

      def digit?(byte)
        !byte.nil? && byte >= 0x30 && byte <= 0x39
      end

      def hex_digit?(byte)
        return false if byte.nil?
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x46) || (byte >= 0x61 && byte <= 0x66)
      end

      def valid_hex4?(str)
        return false unless str && str.length == 4
        i = 0
        while i < 4
          return false unless hex_digit?(str.getbyte(i))
          i += 1
        end
        true
      end
    end
  end

  class Server
    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    def initialize(host: "0.0.0.0", port: 8550, manifest: nil)
      @host = host
      @port = port
      @manifest = manifest
      @running = false
      @server_socket = nil
    end

    def start
      @server_socket = TCPServer.new(@host, @port)
      @running = true
      while @running
        socket = @server_socket.accept
        handle_socket(socket) if socket
      end
    rescue Interrupt
      nil
    ensure
      stop
    end

    def stop
      @running = false
      @server_socket.close if @server_socket
      @server_socket = nil
    rescue StandardError
      nil
    end

    private

    def handle_socket(socket)
      ws = nil
      begin
        path, headers = read_http_upgrade_request(socket)
        return unless websocket_upgrade_request?(path, headers)
        send_handshake_response(socket, headers["sec-websocket-key"])
        ws = RufletProd::WebSocketConnection.new(socket)
        while (raw = ws.read_message)
          action, payload = decode_incoming(raw)
          if action == Protocol::ACTIONS[:register_client] || action == Protocol::ACTIONS[:register_web_client]
            on_register_client(ws, payload || {})
          end
        end
      rescue StandardError
        nil
      ensure
        ws.close if ws
        socket.close if socket
      end
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
      return false unless headers["upgrade"] && headers["upgrade"].downcase == "websocket"
      return false unless headers["connection"] && headers["connection"].downcase.index("upgrade")
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

    def decode_incoming(raw)
      parsed = RufletProd::WireCodec.unpack(raw.to_s)
      if parsed.is_a?(Array) && parsed.length >= 2
        [parsed[0], parsed[1]]
      elsif parsed.is_a?(Hash)
        [parsed["action"], parsed["payload"]]
      else
        [nil, nil]
      end
    end

    def on_register_client(ws, payload)
      normalized = Protocol.normalize_register_payload(payload)
      session_id = normalized["session_id"].to_s.empty? ? "ruflet-#{rand(0xffffffff).to_s(16)}" : normalized["session_id"]
      initial_response = [Protocol::ACTIONS[:register_client], { "session_id" => session_id, "page_patch" => {}, "error" => nil }]
      ws.send_binary(RufletProd::WireCodec.pack(initial_response))
      replay_manifest(ws)
    end

    def replay_manifest(ws)
      return unless @manifest.is_a?(Hash)
      manifest_messages = @manifest["messages"]
      return unless manifest_messages.is_a?(Array)
      manifest_messages.each do |message|
        action = message["action"] || message[:action]
        payload = message["payload"] || message[:payload] || {}
        ws.send_binary(RufletProd::WireCodec.pack([action, payload]))
      end
    end

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

      idx = 0
      while idx < bytes.bytesize
        chunk = bytes[idx, 64]
        idx += 64
        c = chunk.bytes
        w = Array.new(80, 0)
        i = 0
        while i < 16
          j = i * 4
          w[i] = ((c[j] << 24) | (c[j + 1] << 16) | (c[j + 2] << 8) | c[j + 3]) & 0xffffffff
          i += 1
        end
        while i < 80
          v = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
          w[i] = ((v << 1) | (v >> 31)) & 0xffffffff
          i += 1
        end

        a = h0
        b = h1
        c2 = h2
        d = h3
        e = h4
        i = 0
        while i < 80
          if i < 20
            f = ((b & c2) | ((~b) & d)) & 0xffffffff
            k = 0x5A827999
          elsif i < 40
            f = (b ^ c2 ^ d) & 0xffffffff
            k = 0x6ED9EBA1
          elsif i < 60
            f = ((b & c2) | (b & d) | (c2 & d)) & 0xffffffff
            k = 0x8F1BBCDC
          else
            f = (b ^ c2 ^ d) & 0xffffffff
            k = 0xCA62C1D6
          end
          temp = ((((a << 5) | (a >> 27)) & 0xffffffff) + f + e + k + w[i]) & 0xffffffff
          e = d
          d = c2
          c2 = ((b << 30) | (b >> 2)) & 0xffffffff
          b = a
          a = temp
          i += 1
        end
        h0 = (h0 + a) & 0xffffffff
        h1 = (h1 + b) & 0xffffffff
        h2 = (h2 + c2) & 0xffffffff
        h3 = (h3 + d) & 0xffffffff
        h4 = (h4 + e) & 0xffffffff
      end
      [h0, h1, h2, h3, h4].pack("N5")
    end
  end
end
