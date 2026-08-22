# frozen_string_literal: true

require_relative "test_helper"

class RufletServerTransportTest < Minitest::Test
  class FakeBridge
    attr_reader :written

    def initialize
      @written = []
    end

    def __bridge_read
      nil
    end

    def __bridge_write(payload)
      @written << payload
    end

    def __bridge_close
      nil
    end
  end

  def test_in_process_mode_does_not_bind_a_tcp_port
    occupied = TCPServer.new("127.0.0.1", 0)
    bridge = FakeBridge.new
    previous_transport = ENV["RUFLET_RUNTIME_TRANSPORT"]
    previous_strict_port = ENV["RUFLET_STRICT_PORT"]
    ENV["RUFLET_RUNTIME_TRANSPORT"] = "in_process"
    ENV["RUFLET_STRICT_PORT"] = "1"

    server = Ruflet::Server.new(
      host: "127.0.0.1",
      port: occupied.addr[1],
      in_process_bridge: bridge
    ) { |_page| nil }

    server.start

    assert_nil server.instance_variable_get(:@server_socket)
    assert_empty bridge.written
  ensure
    server&.stop
    occupied&.close
    ENV["RUFLET_RUNTIME_TRANSPORT"] = previous_transport
    ENV["RUFLET_STRICT_PORT"] = previous_strict_port
  end

  def test_in_process_mode_never_falls_back_when_bridge_is_invalid
    previous_transport = ENV["RUFLET_RUNTIME_TRANSPORT"]
    ENV["RUFLET_RUNTIME_TRANSPORT"] = "in_process"
    server = Ruflet::Server.new(in_process_bridge: Object.new) { |_page| nil }

    error = assert_raises(RuntimeError) { server.start }

    assert_includes error.message, "Ruflet in-process bridge is missing"
    assert_nil server.instance_variable_get(:@server_socket)
  ensure
    server&.stop
    ENV["RUFLET_RUNTIME_TRANSPORT"] = previous_transport
  end
end
