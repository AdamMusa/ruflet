# frozen_string_literal: true

require "tmpdir"

require_relative "test_helper"

class RufletServerBindTest < Minitest::Test
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

  def test_bound_port_is_published_to_port_file_and_removed_on_stop
    occupied = TCPServer.new("127.0.0.1", 0)
    busy_port = occupied.addr[1]
    port_file = File.join(Dir.mktmpdir("ruflet_port_test"), "server.port")
    previous = ENV["RUFLET_PORT_FILE"]
    ENV["RUFLET_PORT_FILE"] = port_file

    server = Ruflet::Server.new(host: "127.0.0.1", port: busy_port) { |_page| nil }

    begin
      server.bind_server_socket!(max_attempts: 2)
      assert_equal (busy_port + 1).to_s, File.read(port_file)

      server.stop
      refute File.exist?(port_file), "stop should remove the port file"
    ensure
      server.stop
      occupied.close
      ENV["RUFLET_PORT_FILE"] = previous
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
