# frozen_string_literal: true

module Ruflet
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
end
