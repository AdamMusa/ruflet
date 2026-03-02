# frozen_string_literal: true

module RufletProd
  class WebSocketConnection
    def initialize(socket)
      @socket = socket
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
      send_frame(0x2, payload.to_s)
    end

    def read_message
      frame = read_frame
      return nil if frame.nil?

      case frame[:opcode]
      when 0x8
        close
        nil
      when 0x9
        send_frame(0xA, frame[:payload])
        read_message
      when 0xA
        read_message
      when 0x1, 0x2
        frame[:payload]
      else
        read_message
      end
    end

    def close
      return if closed?

      @socket.close
    rescue IOError
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
      payload = payload_len.zero? ? "" : read_exact(payload_len)
      return nil if payload.nil?

      payload = unmask(payload, masking_key) if masked
      { opcode: b1 & 0x0f, payload: payload }
    end

    def send_frame(opcode, payload)
      bytes = payload.to_s
      len = bytes.bytesize
      header = [0x80 | (opcode & 0x0f)].pack("C")

      header += if len <= 125
                  [len].pack("C")
                elsif len <= 0xffff
                  [126].pack("C") + [len].pack("n")
                else
                  [127].pack("C") + [len].pack("Q>")
                end

      @socket.write(header)
      @socket.write(bytes) unless bytes.empty?
    end

    def unmask(payload, mask)
      out = "".dup
      payload.bytes.each_with_index do |byte, idx|
        out += [(byte ^ mask.getbyte(idx % 4))].pack("C")
      end
      out
    end

    def read_exact(length)
      chunk = "".dup

      while chunk.bytesize < length
        part = @socket.read(length - chunk.bytesize)
        return nil if part.nil? || part.empty?

        chunk += part
      end

      chunk
    end
  end
end
