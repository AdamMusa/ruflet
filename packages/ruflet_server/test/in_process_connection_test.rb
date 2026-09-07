# frozen_string_literal: true

require_relative "test_helper"
require "ruflet/server/in_process_connection"

class RufletInProcessConnectionTest < Minitest::Test
  class FakeBridge
    attr_reader :written, :close_count

    def initialize(incoming = [])
      @incoming = incoming
      @written = []
      @close_count = 0
    end

    def __bridge_read_nonblock
      @incoming.empty? ? false : @incoming.shift
    end

    def __bridge_write(payload)
      @written << payload
    end

    def __bridge_close
      @close_count += 1
    end
  end

  def test_moves_binary_messages_without_websocket_framing
    bridge = FakeBridge.new(["from renderer".b])
    connection = Ruflet::InProcessConnection.new(bridge: bridge)

    assert_equal "from renderer".b, connection.read_message

    connection.send_binary("from ruby".b)
    assert_equal ["from ruby".b], bridge.written
  end

  def test_nil_message_closes_the_connection
    connection = Ruflet::InProcessConnection.new(bridge: FakeBridge.new([nil]))

    assert_nil connection.read_message
    assert connection.closed?
  end

  def test_waits_across_empty_reads_without_closing_the_connection
    bridge = FakeBridge.new([false, false, "next frame".b])
    connection = Ruflet::InProcessConnection.new(bridge: bridge)

    assert_equal "next frame".b, connection.read_message
    refute connection.closed?
  end

  def test_close_is_idempotent
    bridge = FakeBridge.new
    connection = Ruflet::InProcessConnection.new(bridge: bridge)

    connection.close
    connection.close

    assert_equal 1, bridge.close_count
  end

  def test_missing_bridge_contract_is_an_explicit_error
    error = assert_raises(RuntimeError) do
      Ruflet::InProcessConnection.new(bridge: Object.new)
    end

    assert_includes error.message, "__bridge_read_nonblock"
    assert_includes error.message, "__bridge_write"
    assert_includes error.message, "__bridge_close"
  end

  def test_rejects_messages_larger_than_the_protocol_limit
    bridge = FakeBridge.new
    connection = Ruflet::InProcessConnection.new(bridge: bridge)
    oversized = "x" * (Ruflet::InProcessConnection::MAX_MESSAGE_BYTES + 1)

    assert_raises(ArgumentError) { connection.send_binary(oversized) }
    assert_empty bridge.written
  end
end
