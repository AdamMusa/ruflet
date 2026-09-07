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

  private

  def frame(fin:, opcode:, payload:)
    first = (fin ? 0x80 : 0) | opcode
    length = payload.bytesize
    [first, length].pack("CC") + payload
  end
end
