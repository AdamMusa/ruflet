# frozen_string_literal: true

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
end
