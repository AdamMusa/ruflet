# frozen_string_literal: true

require_relative "test_helper"
require "socket"

# A plain HTTP client that hangs up before the response is written (the
# `ruflet run` boot probe writes its request and closes; a browser cancels a
# request) is not a server error.
class RufletServerHttpDisconnectTest < Minitest::Test
  # Accepts the status line, then fails every later write with `error`, as a
  # socket whose peer has gone does.
  class HungUpSocket
    attr_reader :written

    def initialize(error)
      @error = error
      @written = +""
    end

    def write(data)
      raise @error, "peer went away" unless @written.empty?

      @written << data.to_s
      data.to_s.bytesize
    end
  end

  def test_a_client_that_hung_up_mid_response_is_not_reported
    [Errno::EPIPE, Errno::ECONNRESET, IOError].each do |error|
      server = Ruflet::Server.new
      socket = HungUpSocket.new(error)

      _out, err = capture_io { server.send(:handle_http_request, socket, "/") }

      assert_empty err, error.name
      assert_equal "HTTP/1.1 200 OK\r\n", socket.written, "no 500 is attempted on a dead socket (#{error.name})"
    end
  end

  # Anything else still is a server error, answered with a 500.
  def test_other_errors_are_still_reported_with_a_500
    server = Ruflet::Server.new
    server.define_singleton_method(:serve_web_client) { |_socket, _path| raise ArgumentError, "broken" }
    socket = HungUpSocket.new(Errno::EPIPE)
    def socket.write(data)
      @written << data.to_s
      data.to_s.bytesize
    end

    _out, err = capture_io { server.send(:handle_http_request, socket, "/") }

    assert_includes err, "http error: ArgumentError: broken"
    assert_includes socket.written, "HTTP/1.1 500 Internal Server Error\r\n"
  end

  # End to end: requests whose client closes at once, as the boot probe does.
  # Whether a write lands after the close is timing; the warning must never
  # appear either way.
  def test_requests_closed_before_the_response_leave_no_http_error
    server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| }
    listener = TCPServer.new("127.0.0.1", 0)
    port = listener.addr[1]
    handlers = []
    _out, err = capture_io do
      acceptor = Thread.new do
        50.times do
          client = listener.accept
          handlers << Thread.new(client) do |socket|
            server.send(:handle_socket, socket)
          rescue StandardError
            nil
          end
        end
      end
      50.times do
        sock = TCPSocket.new("127.0.0.1", port)
        sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [1, 0].pack("ii"))
        sock.write("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        sock.close
      end
      acceptor.join(30)
      handlers.each { |thread| thread.join(5) }
    end

    refute_match(/http error/, err)
  ensure
    listener&.close
  end
end
