# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class RufletWebSocketConnectionTest < Minitest::Test
  def test_read_message_reassembles_fragmented_binary_frames
    socket = StringIO.new(frame(fin: false, opcode: 0x2, payload: "part-1") + frame(fin: true, opcode: 0x0, payload: "part-2"))
    connection = Ruflet::WebSocketConnection.new(socket)

    assert_equal "part-1part-2", connection.read_message
  end

  private

  def frame(fin:, opcode:, payload:)
    first = (fin ? 0x80 : 0) | opcode
    length = payload.bytesize
    [first, length].pack("CC") + payload
  end
end
