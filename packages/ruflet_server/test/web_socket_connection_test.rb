# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class RufletWebSocketConnectionTest < Minitest::Test
  def test_read_message_reassembles_fragmented_binary_frames
    socket = StringIO.new(frame(fin: false, opcode: 0x2, payload: "part-1") + frame(fin: true, opcode: 0x0, payload: "part-2"))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_equal "part-1part-2", connection.read_message
  end

  def test_trace_observes_one_complete_message_after_fragment_reassembly
    message = [3, { "target" => 9, "name" => "click", "data" => nil }]
    payload = Ruflet::WireCodec.pack(message)
    split = payload.bytesize / 2
    socket = StringIO.new(
      frame(fin: false, opcode: 0x2, payload: payload.byteslice(0, split)) +
      frame(fin: true, opcode: 0x0, payload: payload.byteslice(split, payload.bytesize - split))
    )
    connection = Ruflet::WebSocketConnection.new(socket)
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV["RUFLET_PROTOCOL_TRACE"] = "1"

    output, = capture_io { assert_equal payload, connection.read_message }

    assert_equal 1, output.scan(/client->ruby conn=\d+/).length
    assert_includes output, "action=3"
    # Ruby 3.4 put spaces around => in Hash#inspect. The trace is a debugging
    # aid, not a wire format, so match either spelling rather than pinning the
    # suite to one Ruby -- these gems support 3.1 and up.
    assert_match(/"target"\s*=>\s*9/, output)
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end

  # ruflet_rails pings the socket that owns a session before another socket
  # may resume it (AdamMusa/ruflet#114). The pong arrives on the connection's
  # own read loop, as in ConnectionProtocol#run_connection.
  def test_ping_is_true_when_the_client_answers_its_pong
    server_io, client_io = UNIXSocket.pair
    connection = Ruflet::WebSocketConnection.new(server_io)
    loop_thread = Thread.new { connection.read_message }
    client = Thread.new do
      Thread.current.report_on_exception = false
      ping = read_server_frame(client_io)
      client_io.write(masked_frame(opcode: 0xA, payload: ping[:payload]))
      ping
    end

    assert_equal true, connection.ping(timeout: 5)
    assert client.join(2), "the client never received a ping"
    assert_equal 0x9, client.value[:opcode]
    assert_equal 8, client.value[:payload].bytesize
  ensure
    [client_io, server_io].each { |io| io&.close unless io&.closed? }
    loop_thread&.join(1)
  end

  def test_ping_is_false_when_no_pong_arrives_in_time
    server_io, client_io = UNIXSocket.pair
    connection = Ruflet::WebSocketConnection.new(server_io)
    loop_thread = Thread.new { connection.read_message }
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    assert_equal false, connection.ping(timeout: 0.2)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :>=, 0.2
  ensure
    [client_io, server_io].each { |io| io&.close unless io&.closed? }
    loop_thread&.join(1)
  end

  def test_a_pong_for_another_ping_does_not_answer
    server_io, client_io = UNIXSocket.pair
    connection = Ruflet::WebSocketConnection.new(server_io)
    loop_thread = Thread.new { connection.read_message }
    client = Thread.new do
      Thread.current.report_on_exception = false
      read_server_frame(client_io)
      client_io.write(masked_frame(opcode: 0xA, payload: "unsolicited".b))
    end

    assert_equal false, connection.ping(timeout: 0.3)
    assert client.join(2), "the client never received a ping"
  ensure
    [client_io, server_io].each { |io| io&.close unless io&.closed? }
    loop_thread&.join(1)
  end

  def test_ping_on_a_closed_connection_is_false
    server_io, client_io = UNIXSocket.pair
    connection = Ruflet::WebSocketConnection.new(server_io)
    connection.close

    assert_equal false, connection.ping(timeout: 1)
  ensure
    client_io&.close
  end

  def test_pongs_still_do_not_end_read_message
    pong = masked_frame(opcode: 0xA, payload: "late".b)
    message = masked_frame(opcode: 0x2, payload: "data".b)
    connection = Ruflet::WebSocketConnection.new(StringIO.new(pong + message))

    assert_equal "data", connection.read_message
  end

  private

  def read_server_frame(io)
    header = io.read(2)
    length = header.getbyte(1) & 0x7f
    { opcode: header.getbyte(0) & 0x0f, payload: io.read(length) }
  end

  def masked_frame(opcode:, payload:)
    mask = [0x12, 0x34, 0x56, 0x78]
    masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }.pack("C*")
    [0x80 | opcode, 0x80 | payload.bytesize].pack("CC") + mask.pack("C4") + masked
  end

  def frame(fin:, opcode:, payload:)
    first = (fin ? 0x80 : 0) | opcode
    length = payload.bytesize
    [first, length].pack("CC") + payload
  end
end
