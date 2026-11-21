# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "securerandom"

# What a client can make the WebSocket reader do before it has registered:
# the CPU one masked frame costs, how far a fragmented message may grow,
# whether control frames can exhaust the stack, and that a refused message
# is reported rather than silently dropped.
class RufletWebSocketConnectionLimitsTest < Minitest::Test
  MASK = "\x8c\x1f\x05\xe3".b

  # Reads from one buffer and records writes in another (a StringIO alone
  # would write each pong over the frames still to be read).
  class DuplexSocket
    attr_reader :written

    def initialize(incoming)
      @incoming = StringIO.new(incoming)
      @written = +"".b
    end

    def read(length) = @incoming.read(length)
    def write(bytes) = (@written << bytes.b).bytesize
    def closed? = false
    def close = nil
  end

  def test_a_16_mib_masked_frame_is_unmasked_in_well_under_a_second_of_cpu
    payload = SecureRandom.random_bytes(Ruflet::WebSocketConnection::MAX_FRAME_PAYLOAD_BYTES)
    key = MASK.unpack1("N")
    masked = payload.unpack("N*").map! { |word| word ^ key }.pack("N*")
    socket = StringIO.new(frame_header(0x2, payload.bytesize, masked: true) + MASK + masked)
    connection = Ruflet::WebSocketConnection.new(socket)

    started = thread_cpu
    message = connection.read_message
    cpu = thread_cpu - started

    assert payload == message, "the unmasked 16 MiB message differs from what was sent"
    # The per-byte loop this replaced took about 1.8 s of CPU here.
    assert_operator cpu, :<, 1.0, "unmasking 16 MiB took #{cpu.round(2)} s of CPU"
  end

  def test_every_unmask_strategy_returns_the_same_bytes
    connection = Ruflet::WebSocketConnection.new(StringIO.new)
    strategies = %i[unmask_words unmask_bytes]
    strategies << :unmask_io_buffer if Ruflet::WebSocketConnection::UNMASK_STRATEGY == :io_buffer

    lengths = (1..9).to_a + [125, 126, 65_535, 65_536, (1 << 20) + 3]
    lengths.each do |length|
      payload = SecureRandom.random_bytes(length)
      mask = SecureRandom.random_bytes(4)
      expected = reference_unmask(payload, mask)

      strategies.each do |strategy|
        out = connection.send(strategy, payload, mask)
        assert expected == out, "#{strategy} differs for #{length} bytes"
        assert_equal Encoding::BINARY, out.encoding
      end
      assert expected == connection.send(:unmask, payload, mask), "unmask differs for #{length} bytes"
    end
  end

  def test_a_fragmented_message_may_reach_the_limit_but_not_pass_it
    at_limit = StringIO.new(frame(0x2, "a" * 512, fin: false) + frame(0x0, "b" * 512))
    connection = Ruflet::WebSocketConnection.new(at_limit, max_message_bytes: 1024)
    assert_equal ("a" * 512) + ("b" * 512), connection.read_message
    assert_nil connection.message_limit_error

    over = StringIO.new(frame(0x2, "a" * 600, fin: false) + frame(0x0, "b" * 600))
    connection = Ruflet::WebSocketConnection.new(over, max_message_bytes: 1024)

    assert_nil connection.read_message
    error = connection.message_limit_error
    assert_kind_of Ruflet::MessageTooLargeError, error
    assert_equal 1200, error.bytes
    assert_equal 1024, error.limit
    # Refused on the declared length: the second payload was never read.
    assert_equal 600, over.size - over.pos
  end

  def test_two_full_size_fragments_are_refused_at_the_default_limit
    half = Ruflet::WebSocketConnection::MAX_FRAME_PAYLOAD_BYTES
    socket = StringIO.new(frame_header(0x2, half, fin: false) + ("\x00".b * half) + frame_header(0x0, half))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_nil connection.read_message
    assert_equal 2 * half, connection.message_limit_error.bytes
  end

  def test_a_frame_declaring_more_than_the_limit_is_reported_without_reading_it
    declared = Ruflet::WebSocketConnection::MAX_FRAME_PAYLOAD_BYTES + 1
    connection = Ruflet::WebSocketConnection.new(StringIO.new(frame_header(0x2, declared)))

    assert_nil connection.read_message
    error = connection.message_limit_error
    assert_equal declared, error.bytes
    assert_includes error.message, "RUFLET_MAX_MESSAGE_BYTES"
    assert_includes error.message, Ruflet::WebSocketConnection::MAX_FRAME_PAYLOAD_BYTES.to_s
  end

  def test_thousands_of_pings_and_pongs_before_a_message_do_not_exhaust_the_stack
    socket = DuplexSocket.new(("\x8a\x00".b * 100_000) + ("\x89\x00".b * 20_000) + frame(0x2, "hello", mask: MASK))
    connection = Ruflet::WebSocketConnection.new(socket)

    # In a thread, like every server connection: its stack is the smallest.
    message = Thread.new { connection.read_message }.value

    assert_equal "hello", message
    assert_equal ("\x8a\x00".b * 20_000), socket.written, "every ping is answered"
  end

  def test_pings_inside_a_fragmented_message_are_answered_in_the_same_loop
    socket = DuplexSocket.new(frame(0x2, "par", fin: false) + ("\x89\x00".b * 50_000) + frame(0x0, "ts"))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_equal "parts", Thread.new { connection.read_message }.value
    assert_equal ("\x8a\x00".b * 50_000), socket.written
  end

  def test_a_control_frame_over_125_bytes_ends_the_connection
    socket = DuplexSocket.new(frame(0x9, "p" * 126) + frame(0x2, "never read"))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_nil connection.read_message
    assert_nil connection.message_limit_error
    assert_empty socket.written, "no pong is echoed"
  end

  def test_a_125_byte_ping_is_still_answered
    socket = DuplexSocket.new(frame(0x9, "p" * 125) + frame(0x2, "next"))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_equal "next", connection.read_message
    assert_equal frame(0xA, "p" * 125), socket.written
  end

  def test_the_limit_comes_from_ruflet_max_message_bytes
    with_env("RUFLET_MAX_MESSAGE_BYTES" => "2048") do
      connection = Ruflet::WebSocketConnection.new(StringIO.new(frame(0x2, "x" * 2048) + frame(0x2, "y" * 2049)))

      assert_equal 2048, connection.max_message_bytes
      assert_equal "x" * 2048, connection.read_message
      assert_nil connection.read_message
      assert_equal 2049, connection.message_limit_error.bytes
    end
  end

  def test_an_invalid_ruflet_max_message_bytes_keeps_the_default_and_says_so
    with_env("RUFLET_MAX_MESSAGE_BYTES" => "sixteen megabytes") do
      _out, err = capture_io do
        connection = Ruflet::WebSocketConnection.new(StringIO.new)
        assert_equal Ruflet::ServerLimits::DEFAULT_MAX_MESSAGE_BYTES, connection.max_message_bytes
      end

      assert_includes err, "RUFLET_MAX_MESSAGE_BYTES"
    end
  end

  def test_unmasking_does_not_print_the_io_buffer_experimental_warning
    _out, err = capture_subprocess_io do
      lib = File.expand_path("../lib", __dir__)
      core = File.expand_path("../../ruflet_core/lib", __dir__)
      script = <<~RUBY
        require "ruflet_server"
        require "stringio"
        payload = "abcd".b
        frame = [0x82, 0x84].pack("CC") + "\\x01\\x02\\x03\\x04".b + payload
        Ruflet::WebSocketConnection.new(StringIO.new(frame)).read_message
      RUBY
      system(RbConfig.ruby, "-I", core, "-I", lib, "-e", script)
    end

    refute_match(/experimental/, err)
  end

  private

  def thread_cpu
    Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
  end

  def reference_unmask(payload, mask)
    payload.bytes.each_with_index.map { |byte, index| byte ^ mask.getbyte(index % 4) }.pack("C*")
  end

  def frame(opcode, payload, fin: true, mask: nil)
    bytes = payload.b
    body = mask ? reference_unmask(bytes, mask) : bytes
    frame_header(opcode, bytes.bytesize, fin: fin, masked: !mask.nil?) + (mask || "".b) + body
  end

  def frame_header(opcode, length, fin: true, masked: false)
    first = (fin ? 0x80 : 0) | opcode
    mask_bit = masked ? 0x80 : 0
    if length <= 125
      [first, mask_bit | length].pack("CC")
    elsif length <= 0xffff
      [first, mask_bit | 126, length].pack("CCn")
    else
      [first, mask_bit | 127, length].pack("CCQ>")
    end
  end

  def with_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
