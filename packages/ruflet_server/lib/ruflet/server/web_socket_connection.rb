# frozen_string_literal: true

require_relative "limits"

module Ruflet
  class WebSocketConnection
    TASK_IO_POLL_INTERVAL = 0.01
    # Ruflet control messages are small; anything much larger is invalid or
    # hostile. This is the default limit on one message, however many frames
    # carry it; RUFLET_MAX_MESSAGE_BYTES changes it.
    MAX_FRAME_PAYLOAD_BYTES = ServerLimits::DEFAULT_MAX_MESSAGE_BYTES
    # RFC 6455 section 5.5: a ping, pong or close frame carries at most 125
    # bytes.
    MAX_CONTROL_PAYLOAD_BYTES = 125

    # How frames are unmasked. IO::Buffer#xor! runs in C, about 80 times
    # faster than a Ruby loop over the bytes. Without it, CRuby xors 32-bit
    # words; mruby keeps the byte loop (its integers may be 32-bit).
    UNMASK_STRATEGY =
      begin
        if Object.const_defined?(:IO) && IO.const_defined?(:Buffer) && IO::Buffer.method_defined?(:xor!)
          # IO::Buffer prints a one-time "experimental" warning on first use.
          # Use it once here with that category silenced, so applications do
          # not see a new warning the first time a client sends a frame.
          previous = Warning[:experimental]
          begin
            Warning[:experimental] = false
            IO::Buffer.new(1).free
          ensure
            Warning[:experimental] = previous
          end
          :io_buffer
        elsif RUBY_ENGINE == "mruby"
          :bytes
        else
          :words
        end
      rescue StandardError
        RUBY_ENGINE == "mruby" ? :bytes : :words
      end

    attr_reader :max_message_bytes

    # The Ruflet::MessageTooLargeError behind the last nil from read_message,
    # or nil when the connection ended for another reason.
    attr_reader :message_limit_error

    def initialize(socket, max_message_bytes: nil)
      @socket = socket
      @write_mutex = Mutex.new
      @max_message_bytes = max_message_bytes || ServerLimits.max_message_bytes
      @message_limit_error = nil
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
      bytes = payload.to_s.b
      Ruflet::WireCodec.trace("ruby->client conn=#{session_key}", bytes, max_depth: nil)
      send_frame(0x2, bytes)
    end

    def send_text(payload)
      send_frame(0x1, payload.to_s.b)
    end

    # Returns the next complete data message, or nil once the connection is
    # closed or the client breaks the protocol. Pings are answered and pongs
    # skipped in a loop, so no number of them can exhaust the stack.
    def read_message
      message = nil

      loop do
        frame = read_frame(message ? message.bytesize : 0)
        return nil if frame.nil?

        opcode = frame[:opcode]
        payload = frame[:payload]

        if message.nil?
          case opcode
          when 0x8
            close
            return nil
          when 0x9
            send_frame(0xA, payload)
          when 0xA
            nil
          when 0x1, 0x2
            return traced_incoming(payload) if frame[:fin]

            message = payload.dup
          end
          # Any other opcode outside a fragmented message is ignored.
        else
          case opcode
          when 0x9
            send_frame(0xA, payload)
          when 0xA
            nil
          when 0x0
            message << payload
            return traced_incoming(message) if frame[:fin]
          else
            return nil
          end
        end
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

    def traced_incoming(payload)
      Ruflet::WireCodec.trace("client->ruby conn=#{session_key}", payload)
      payload
    end

    # message_bytes: bytes of the fragmented message read so far. A data
    # frame may only bring the message up to max_message_bytes; its declared
    # length is checked before any payload byte is read.
    def read_frame(message_bytes = 0)
      header = read_exact(2)
      return nil if header.nil?

      b1 = header.getbyte(0)
      b2 = header.getbyte(1)

      fin = (b1 & 0x80) != 0
      opcode = b1 & 0x0f
      masked = (b2 & 0x80) != 0
      payload_len = b2 & 0x7f

      if payload_len == 126
        ext = read_exact(2)
        return nil if ext.nil?
        payload_len = ext.unpack1("n")
      elsif payload_len == 127
        ext = read_exact(8)
        return nil if ext.nil?
        payload_len = ext.unpack1("Q>")
      end

      return nil if payload_len.negative?

      if (opcode & 0x8) != 0
        return nil if payload_len > MAX_CONTROL_PAYLOAD_BYTES
      elsif payload_len > @max_message_bytes - message_bytes
        @message_limit_error = MessageTooLargeError.new(bytes: message_bytes + payload_len, limit: @max_message_bytes)
        return nil
      end

      masking_key = masked ? read_exact(4) : nil
      return nil if masked && masking_key.nil?
      payload = payload_len.zero? ? "".b : read_exact(payload_len)
      return nil if payload.nil?

      payload = unmask(payload, masking_key) if masked

      { fin: fin, opcode: opcode, payload: payload }
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
        @socket.write(header + bytes)
        @socket.flush if @socket.respond_to?(:flush)
      end
    end

    def unmask(payload, mask)
      return payload if payload.empty?

      case UNMASK_STRATEGY
      when :io_buffer then unmask_io_buffer(payload, mask)
      when :words then unmask_words(payload, mask)
      else unmask_bytes(payload, mask)
      end
    end

    def unmask_io_buffer(payload, mask)
      buffer = IO::Buffer.new(payload.bytesize)
      buffer.set_string(payload)
      buffer.xor!(IO::Buffer.for(mask))
      buffer.get_string
    ensure
      buffer&.free
    end

    def unmask_words(payload, mask)
      whole = payload.bytesize - (payload.bytesize % 4)
      key = mask.unpack1("N")
      out = payload.byteslice(0, whole).unpack("N*").map! { |word| word ^ key }.pack("N*")
      index = whole
      while index < payload.bytesize
        out << (payload.getbyte(index) ^ mask.getbyte(index - whole))
        index += 1
      end
      out
    end

    def unmask_bytes(payload, mask)
      out = +""
      out.force_encoding(Encoding::BINARY)
      payload.bytes.each_with_index do |byte, idx|
        out << (byte ^ mask.getbyte(idx % 4))
      end
      out
    end

    def read_exact(length)
      return nil unless length.is_a?(Integer)
      return nil if length.negative? || length > @max_message_bytes

      chunk = +""
      chunk.force_encoding(Encoding::BINARY)

      while chunk.bytesize < length
        part = if task_scheduler?
          @socket.recv_nonblock(length - chunk.bytesize)
        else
          @socket.read(length - chunk.bytesize)
        end
        return nil if part.nil? || part.empty?

        chunk << part
      end

      chunk
    rescue StandardError => error
      if task_scheduler? && would_block_error?(error)
        sleep TASK_IO_POLL_INTERVAL
        retry
      end

      nil
    end

    def task_scheduler?
      concurrent = Object.const_defined?(:Task) || (Thread.respond_to?(:cooperative?) && Thread.cooperative?)
      concurrent && @socket.respond_to?(:recv_nonblock)
    end

    def would_block_error?(error)
      %w[Errno::EAGAIN Errno::EWOULDBLOCK IO::EAGAINWaitReadable IO::WaitReadable].include?(error.class.to_s)
    end
  end
end
