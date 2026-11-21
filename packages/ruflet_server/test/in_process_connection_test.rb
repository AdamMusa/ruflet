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

  def test_the_limit_comes_from_ruflet_max_message_bytes
    previous = ENV["RUFLET_MAX_MESSAGE_BYTES"]
    ENV["RUFLET_MAX_MESSAGE_BYTES"] = "64"
    bridge = FakeBridge.new(["a" * 64, "b" * 65])
    connection = Ruflet::InProcessConnection.new(bridge: bridge)

    assert_equal 64, connection.max_message_bytes
    assert_equal "a" * 64, connection.read_message
    error = assert_raises(Ruflet::MessageTooLargeError) { connection.read_message }
    assert_kind_of ArgumentError, error
    assert_same error, connection.message_limit_error
    assert_includes error.message, "a client message of at least 65 bytes exceeds the 64-byte limit, so the connection was closed"
    assert_includes error.message, "RUFLET_MAX_MESSAGE_BYTES"

    # Refusing to send a message does not close anything, so its error
    # must not say it did.
    outgoing = assert_raises(Ruflet::MessageTooLargeError) { connection.send_binary("c" * 65) }
    assert_includes outgoing.message, "a 65-byte message to the client exceeds the 64-byte limit, so it was not sent"
    refute_includes outgoing.message, "closed"
    assert_includes outgoing.message, "RUFLET_MAX_MESSAGE_BYTES"
    assert_empty bridge.written
  ensure
    ENV["RUFLET_MAX_MESSAGE_BYTES"] = previous
  end

  # Ruflet::Server's in-process loop: the oversized message is logged once
  # (as before, with session_crashed) and the invokes waiting on the client
  # end with the error instead of hanging.
  def test_the_server_fails_pending_invokes_when_an_in_process_message_is_too_large
    previous = ENV["RUFLET_MAX_MESSAGE_BYTES"]
    ENV["RUFLET_MAX_MESSAGE_BYTES"] = "4096"
    register = Ruflet::WireCodec.pack([Ruflet::Protocol::ACTIONS[:register_client], { "session_id" => "s", "page" => { "route" => "/" } }])
    bridge = FakeBridge.new([register, "x" * 5000])
    results = []
    server = Ruflet::Server.new(in_process_bridge: bridge) do |page|
      page.invoke(1, "pick_files", timeout: nil, on_result: ->(result, error) { results << [result, error] })
    end

    _out, err = capture_io { server.send(:run_connection, Ruflet::InProcessConnection.new(bridge: bridge)) }

    assert_equal 1, results.size
    assert_includes results[0][1], "the 4096-byte limit"
    assert_equal 1, err.scan("Ruflet::MessageTooLargeError").size, err
    crashed = bridge.written.map { |bytes| Ruflet::WireCodec.unpack(bytes)[0] }
    assert_includes crashed, Ruflet::Protocol::ACTIONS[:session_crashed]
  ensure
    ENV["RUFLET_MAX_MESSAGE_BYTES"] = previous
  end

  # A Ruflet::ConnectionProtocol host (ruflet_rails' endpoint) over the
  # in-process transport, whose read_message raises instead of returning
  # nil: the error reaches run_connection's rescue and close_connection,
  # and is logged once, not by both.
  class ProtocolHost
    include Ruflet::ConnectionProtocol

    attr_reader :logged

    def initialize(&app)
      @app_block = app
      @sessions = {}
      @sessions_mutex = Mutex.new
      @logged = []
    end

    def log_connection_error(error)
      @logged << "#{error.class}: #{error.message}"
    end
  end

  def test_connection_protocol_logs_an_in_process_message_over_the_limit_once
    register = Ruflet::WireCodec.pack([Ruflet::Protocol::ACTIONS[:register_client], { "session_id" => "s", "page" => { "route" => "/" } }])
    bridge = FakeBridge.new([register, "x" * 5000])
    results = []
    host = ProtocolHost.new do |page|
      page.invoke(1, "pick_files", timeout: nil, on_result: ->(result, error) { results << [result, error] })
    end
    connection = Ruflet::InProcessConnection.new(bridge: bridge, max_message_bytes: 4096)

    host.run_connection(connection)

    assert_equal 1, host.logged.size, host.logged.inspect
    assert_match(/\ARuflet::MessageTooLargeError: a client message of at least 5000 bytes/, host.logged[0])
    assert_equal 1, results.size
    assert_nil results[0][0]
    assert_includes results[0][1], "the 4096-byte limit"
    sent = bridge.written.map { |bytes| Ruflet::WireCodec.unpack(bytes)[0] }
    assert_includes sent, Ruflet::Protocol::ACTIONS[:session_crashed]
    assert connection.closed?
  end
end
