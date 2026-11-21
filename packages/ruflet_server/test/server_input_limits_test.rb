# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"
require "base64"
require "io/wait"

# A live Ruflet::Server on an ephemeral port, driven by raw sockets the way a
# hostile or broken client would: what it costs before the client registers,
# and that a legitimate client is served exactly as before.
class RufletServerInputLimitsTest < Minitest::Test
  ACTIONS = Ruflet::Protocol::ACTIONS
  REPLY_WAIT = 5
  BUDGET = Ruflet::Server::HTTP_REQUEST_HEAD_MAX_BYTES

  def setup
    @env = {}
    set_env("RUFLET_SUPPRESS_SERVER_BANNER", "1")
    @servers = []
    @clients = []
  end

  def teardown
    @clients.each { |client| client.close unless client.closed? }
    @servers.each(&:stop)
    @env.each { |key, value| ENV[key] = value }
  end

  # -- HTTP before the upgrade ---------------------------------------------

  def test_an_http_response_closes_the_socket
    server = start_server
    5.times do
      response = http_exchange(server, "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

      assert_match(%r{\AHTTP/1\.1 200 OK\r\n}, response)
      assert response.end_with?("\r\n\r\nok"), response
    end
  end

  # The request is exactly the budget long, so the server has read all of it
  # when it answers and its close cannot turn into a reset that drops the
  # response. Before, it waited for a CRLF that never came, buffering
  # whatever arrived.
  def test_a_header_line_that_never_ends_gets_431_instead_of_growing_memory
    server = start_server
    head = "GET / HTTP/1.1\r\nX-Flood: "

    response = http_exchange(server, head + ("a" * (BUDGET - head.bytesize)))

    assert_match(%r{\AHTTP/1\.1 431 Request Header Fields Too Large\r\n}, response)
  end

  # The request ends with the 101st field, the last byte the server reads.
  def test_more_than_100_header_fields_get_431
    server = start_server
    headers = (1..101).map { |n| "X-Field-#{n}: #{n}\r\n" }.join

    response = http_exchange(server, "GET /health HTTP/1.1\r\n#{headers}")

    assert_match(%r{\AHTTP/1\.1 431 }, response)
  end

  # Every line is far under the budget; together they pass it. The request
  # ends exactly at the budget, inside the last line, as above.
  def test_header_lines_that_together_pass_the_budget_get_431
    server = start_server
    head = "GET /health HTTP/1.1\r\n" + (1..4).map { |n| "X-Part-#{n}: #{"a" * 30_000}\r\n" }.join
    last = "X-Last: "

    response = http_exchange(server, head + last + ("b" * (BUDGET - head.bytesize - last.bytesize)))

    assert_match(%r{\AHTTP/1\.1 431 Request Header Fields Too Large\r\n}, response)
  end

  def test_a_request_line_past_the_budget_gets_414
    server = start_server
    response = http_exchange(server, "GET /" + ("p" * (BUDGET - 5)))

    assert_match(%r{\AHTTP/1\.1 414 URI Too Long\r\n}, response)
  end

  def test_large_but_ordinary_requests_are_still_served
    server = start_server
    cookie = (1..20).map { |n| "c#{n}=#{"v" * 3000}" }.join("; ")
    headers = (1..60).map { |n| "X-Field-#{n}: #{n}\r\n" }.join
    request = "GET /health HTTP/1.1\r\nHost: localhost\r\nCookie: #{cookie}\r\n#{headers}Connection: close\r\n\r\n"

    response = http_exchange(server, request)

    assert_match(%r{\AHTTP/1\.1 200 OK\r\n}, response)
  end

  def test_a_request_whose_headers_stall_is_closed_after_the_handshake_deadline
    server = start_server(handshake_timeout: 0.5)
    client = connect(server)
    client.write("GET /health HTTP/1.1\r\nHost: localhost\r\n")

    assert_closed_within(client, 4)
  end

  # -- WebSocket before register --------------------------------------------

  def test_a_websocket_that_sends_nothing_is_closed_after_the_register_deadline
    server = start_server(register_timeout: 0.5)
    client = upgrade(server)

    assert_closed_within(client, 4)
  end

  def test_a_websocket_that_registers_stays_open_past_the_register_deadline
    server = start_server(register_timeout: 0.5) { |page| page.add(Ruflet.text("hello")) }
    client = upgrade(server)
    send_frame(client, Ruflet::WireCodec.pack([ACTIONS[:register_client], { "session_id" => "", "page" => { "route" => "/" } }]))
    action, = Ruflet::WireCodec.unpack(read_frame(client)[:payload])
    assert_equal ACTIONS[:register_client], action

    sleep 1.5
    send_frame(client, "still here", opcode: 0x9)

    frame = nil
    loop do
      frame = read_frame(client)
      break if frame.nil? || frame[:opcode] == 0xA
    end
    refute_nil frame, "the server closed a registered connection"
    assert_equal "still here", frame[:payload]
  end

  def test_ruflet_max_connections_refuses_sockets_past_the_cap
    set_env("RUFLET_MAX_CONNECTIONS", "2")
    server = start_server
    # Connected but silent, so closing them later serves nothing.
    held = [connect(server), connect(server)]
    sleep 0.3

    refused = nil
    _out, err = capture_io do
      # Nothing written: the refusal is sent on accept.
      refused = read_until_closed(connect(server))
    end

    assert_match(%r{\AHTTP/1\.1 503 }, refused)
    assert_includes err, "RUFLET_MAX_CONNECTIONS=2"

    held.each(&:close)
    response = nil
    deadline = monotonic + REPLY_WAIT
    loop do
      response = http_exchange(server, "GET /health HTTP/1.1\r\n\r\n")
      break if response.start_with?("HTTP/1.1 200") || monotonic > deadline

      sleep 0.05
    end
    assert_match(%r{\AHTTP/1\.1 200 OK\r\n}, response, "a slot is free again once a socket closes")
  end

  # A refused client has usually sent its request by the time the server
  # answers. Closing a socket with input still unread sends a reset instead
  # of a normal close, and a reset can cost the client the 503 (Linux
  # discards what the client has not read yet).
  def test_a_refused_client_that_already_sent_its_request_gets_the_503_and_a_clean_close
    set_env("RUFLET_MAX_CONNECTIONS", "1")
    server = start_server
    connect(server) # holds the only slot
    sleep 0.3

    capture_io do
      10.times do |attempt|
        client = connect(server)
        client.write("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n")
        data, error = read_to_eof(client)

        assert_match(%r{\AHTTP/1\.1 503 }, data, "attempt #{attempt}")
        assert_nil error, "attempt #{attempt}: #{error.inspect} after #{data.inspect}"
        client.close
      end

      # A client that reads only after the server has closed: the request
      # was read and dropped first, so there is still no reset.
      client = connect(server)
      client.write("GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n")
      sleep Ruflet::Server::REFUSED_LINGER_SECONDS + 1.0
      data, error = read_to_eof(client)

      assert_match(%r{\AHTTP/1\.1 503 }, data, "late reader")
      assert_nil error, "late reader: #{error.inspect} after #{data.inspect}"
    end
  end

  def test_connections_are_unlimited_without_ruflet_max_connections
    server = start_server
    Array.new(30) { connect(server) }
    sleep 0.3

    response = http_exchange(server, "GET /health HTTP/1.1\r\n\r\n")

    assert_match(%r{\AHTTP/1\.1 200 OK\r\n}, response)
  end

  # -- A message over the limit ----------------------------------------------

  def test_a_message_over_the_limit_is_logged_and_fails_the_pending_invokes
    set_env("RUFLET_MAX_MESSAGE_BYTES", "4096")
    pages = Queue.new
    results = Queue.new
    server = start_server do |page|
      page.invoke(1, "pick_files", args: { "with_data" => true }, timeout: nil,
                  on_result: ->(result, error) { results << [result, error] })
      pages << page
    end

    _out, err = capture_io do
      client = upgrade(server)
      send_frame(client, Ruflet::WireCodec.pack([ACTIONS[:register_client], { "session_id" => "", "page" => { "route" => "/" } }]))
      page = pages.pop(timeout: REPLY_WAIT)
      refute_nil page, "the app block did not run"

      waiter = Thread.new do
        page.invoke_sync(1, "get_device_info", timeout: 60)
        nil
      rescue RuntimeError => e
        e
      end
      wait_until { page.instance_variable_get(:@invoke_waiters).any? }

      send_frame(client, Ruflet::WireCodec.pack([ACTIONS[:invoke_control_method], { "call_id" => "x", "result" => "z" * 5000 }]))

      result, error = results.pop(timeout: REPLY_WAIT)
      assert_nil result
      assert_includes error.to_s, "4096-byte limit"
      assert_includes error.to_s, "RUFLET_MAX_MESSAGE_BYTES"

      raised = waiter.join(REPLY_WAIT)&.value
      assert_kind_of RuntimeError, raised, "invoke_sync kept waiting after the connection closed"
      assert_includes raised.message, "RUFLET_MAX_MESSAGE_BYTES"
      assert_closed_within(client, REPLY_WAIT)
    end

    assert_includes err, "Ruflet::MessageTooLargeError"
  end

  private

  def start_server(handshake_timeout: nil, register_timeout: nil, &app)
    server = Ruflet::Server.new(host: "127.0.0.1", port: 0, &(app || proc { |_page| nil }))
    server.define_singleton_method(:handshake_timeout_seconds) { handshake_timeout } if handshake_timeout
    server.define_singleton_method(:register_timeout_seconds) { register_timeout } if register_timeout
    server.bind_server_socket!
    server.instance_variable_set(:@running, true)
    Thread.new { server.send(:accept_loop) }
    @servers << server
    server
  end

  def connect(server)
    socket = TCPSocket.new("127.0.0.1", server.port)
    @clients << socket
    socket
  end

  def http_exchange(server, request)
    client = connect(server)
    begin
      client.write(request)
    rescue SystemCallError
      nil
    end
    read_until_closed(client)
  end

  def read_until_closed(client, seconds = REPLY_WAIT)
    read_to_eof(client, seconds).first
  end

  # [bytes read, nil] at a normal end of stream, or [bytes read, error]
  # when a reset (a SystemCallError) ended it.
  def read_to_eof(client, seconds = REPLY_WAIT)
    data = +"".b
    deadline = monotonic + seconds
    loop do
      remaining = deadline - monotonic
      flunk "the server did not close the socket within #{seconds}s; read #{data.bytesize} bytes" if remaining <= 0
      next unless client.wait_readable(remaining)

      begin
        chunk = client.read_nonblock(65_536, exception: false)
      rescue SystemCallError => e
        return [data, e]
      end
      next if chunk == :wait_readable
      return [data, nil] if chunk.nil?

      data << chunk
    end
  end

  def assert_closed_within(client, seconds)
    read_until_closed(client, seconds)
    pass
  end

  def upgrade(server)
    client = connect(server)
    key = Base64.strict_encode64(SecureRandom.random_bytes(16))
    client.write("GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" \
                 "Sec-WebSocket-Key: #{key}\r\nSec-WebSocket-Version: 13\r\n\r\n")
    response = +""
    response << client.readpartial(4096) until response.include?("\r\n\r\n")
    assert_match(%r{\AHTTP/1\.1 101 }, response)
    client
  end

  def send_frame(client, payload, opcode: 0x2)
    bytes = payload.b
    mask = SecureRandom.random_bytes(4)
    masked = bytes.bytes.each_with_index.map { |byte, index| byte ^ mask.getbyte(index % 4) }.pack("C*")
    length = bytes.bytesize
    header = if length <= 125
               [0x80 | opcode, 0x80 | length].pack("CC")
             elsif length <= 0xffff
               [0x80 | opcode, 0x80 | 126, length].pack("CCn")
             else
               [0x80 | opcode, 0x80 | 127, length].pack("CCQ>")
             end
    client.write(header + mask + masked)
  end

  def read_frame(client)
    return nil unless client.wait_readable(REPLY_WAIT)

    header = client.read(2)
    return nil if header.nil? || header.bytesize < 2

    length = header.getbyte(1) & 0x7f
    length = client.read(2).unpack1("n") if length == 126
    length = client.read(8).unpack1("Q>") if length == 127
    { opcode: header.getbyte(0) & 0x0f, payload: length.zero? ? "".b : client.read(length) }
  end

  def wait_until(seconds = REPLY_WAIT)
    deadline = monotonic + seconds
    sleep 0.01 until yield || monotonic > deadline
  end

  def set_env(key, value)
    @env[key] = ENV[key] unless @env.key?(key)
    ENV[key] = value
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
