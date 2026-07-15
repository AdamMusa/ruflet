# frozen_string_literal: true

require_relative "test_helper"

class RufletServerBindTest < Minitest::Test
  def test_zero_port_uses_an_os_assigned_port_and_publishes_it
    Dir.mktmpdir do |dir|
      port_file = File.join(dir, "runtime.port")
      previous = ENV["RUFLET_RUNTIME_PORT_FILE"]
      ENV["RUFLET_RUNTIME_PORT_FILE"] = port_file
      server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }

      begin
        server.bind_server_socket!
        assert_operator server.port, :>, 0
        assert_equal server.port, File.read(port_file).to_i
      ensure
        server.stop
        ENV["RUFLET_RUNTIME_PORT_FILE"] = previous
      end
    end
  end

  def test_bind_server_socket_falls_back_to_next_port_when_busy
    occupied = TCPServer.new("127.0.0.1", 0)
    busy_port = occupied.addr[1]

    server = Ruflet::Server.new(host: "127.0.0.1", port: busy_port) { |_page| nil }

    begin
      server.bind_server_socket!(max_attempts: 2)
      assert_equal busy_port + 1, server.port
    ensure
      server.stop
      occupied.close
    end
  end

  def test_strict_port_does_not_fall_back_when_busy
    occupied = TCPServer.new("127.0.0.1", 0)
    busy_port = occupied.addr[1]
    server = Ruflet::Server.new(host: "127.0.0.1", port: busy_port) { |_page| nil }
    previous = ENV["RUFLET_STRICT_PORT"]
    ENV["RUFLET_STRICT_PORT"] = "1"

    assert_raises(Errno::EADDRINUSE) do
      server.bind_server_socket!(max_attempts: 2)
    end
  ensure
    server&.stop
    occupied&.close
    ENV["RUFLET_STRICT_PORT"] = previous
  end
end
