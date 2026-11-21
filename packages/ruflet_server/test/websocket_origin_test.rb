# frozen_string_literal: true

require_relative "test_helper"
require "securerandom"
require "stringio"

# A browser page on another site must not be able to open a socket to the
# dev server `ruflet run` starts, read the page and fire its handlers
# (cross-site WebSocket hijacking). Native clients send no Origin, and the
# web client the dev server serves shares its origin, so both keep working.
# Hosts other than `ruflet run` keep accepting foreign origins, with a
# warning, until they configure allowed origins.
class RufletWebSocketOriginTest < Minitest::Test
  SECRET = "SECRET-TOKEN-abc123"

  def setup
    @saved_env = %w[RUFLET_TARGET RUFLET_ALLOWED_ORIGINS RUFLET_RUNTIME_PORT_FILE RUFLET_SUPPRESS_SERVER_BANNER]
                 .to_h { |key| [key, ENV[key]] }
    ENV.delete("RUFLET_TARGET")
    ENV.delete("RUFLET_ALLOWED_ORIGINS")
    ENV.delete("RUFLET_RUNTIME_PORT_FILE")
    ENV["RUFLET_SUPPRESS_SERVER_BANNER"] = "1"
    @handler_runs = Queue.new
    @log = StringIO.new
    @original_stderr = $stderr
    $stderr = @log
  end

  def teardown
    $stderr = @original_stderr
    @server&.stop
    @server_thread&.join(2)
    @saved_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  # The cswsh_probe from the audit, against the dev server.
  def test_dev_server_refuses_a_foreign_origin_before_the_app_runs
    ENV["RUFLET_TARGET"] = "mobile"
    start_server

    socket, status = handshake(origin: "https://evil.example")
    assert_equal "HTTP/1.1 403 Forbidden", status
    assert_equal "origin not allowed", socket.read, "the refused socket gets the reason and is closed"
    assert_equal 0, @handler_runs.size
    assert_includes @log.string, 'refused a WebSocket connection from Origin "https://evil.example"'
    assert_includes @log.string, "add https://evil.example to RUFLET_ALLOWED_ORIGINS"
  ensure
    socket&.close
  end

  def test_dev_server_logs_each_refused_origin_once
    ENV["RUFLET_TARGET"] = "web"
    start_server

    3.times do
      socket, status = handshake(origin: "https://evil.example")
      assert_equal "HTTP/1.1 403 Forbidden", status
      socket.close
    end

    assert_equal 1, @log.string.scan("refused a WebSocket connection").size
  end

  def test_dev_server_serves_a_native_client_that_sends_no_origin
    ENV["RUFLET_TARGET"] = "mobile"
    start_server

    assert_app_served(origin: nil)
  end

  def test_dev_server_serves_its_own_web_client_on_localhost
    ENV["RUFLET_TARGET"] = "web"
    start_server

    assert_app_served(origin: "http://localhost:#{@server.port}", host: "localhost:#{@server.port}")
  end

  def test_dev_server_serves_its_own_web_client_opened_on_a_lan_address
    ENV["RUFLET_TARGET"] = "web"
    start_server

    assert_app_served(origin: "http://192.168.1.242:#{@server.port}", host: "192.168.1.242:#{@server.port}")
  end

  def test_dev_server_serves_a_page_on_another_local_port
    ENV["RUFLET_TARGET"] = "mobile"
    start_server

    assert_app_served(origin: "http://localhost:5173")
    assert_app_served(origin: "http://127.0.0.1:5173")
    assert_app_served(origin: "http://[::1]:5173")
  end

  def test_dev_server_serves_an_origin_a_proxy_forwarded
    ENV["RUFLET_TARGET"] = "web"
    start_server

    assert_app_served(origin: "https://dev.example.com", host: "127.0.0.1:#{@server.port}",
                      extra_headers: { "X-Forwarded-Host" => "dev.example.com" })
  end

  def test_allowed_origins_env_lets_a_listed_origin_through_the_dev_server
    ENV["RUFLET_TARGET"] = "mobile"
    ENV["RUFLET_ALLOWED_ORIGINS"] = "https://tools.example, https://evil.example"
    start_server

    assert_app_served(origin: "https://evil.example")
    socket, status = handshake(origin: "https://other.example")
    assert_equal "HTTP/1.1 403 Forbidden", status
  ensure
    socket&.close
  end

  def test_a_wildcard_restores_accepting_every_origin_without_a_warning
    ENV["RUFLET_TARGET"] = "mobile"
    ENV["RUFLET_ALLOWED_ORIGINS"] = "*"
    start_server

    assert_app_served(origin: "https://evil.example")
    refute_includes @log.string, "WebSocket connection from Origin"
  end

  # Ruflet.run in production, the embedded runtime and custom hosts: unchanged
  # until they opt in, apart from one warning per foreign origin.
  def test_outside_ruflet_run_a_foreign_origin_is_still_served_and_warned_once
    start_server

    assert_app_served(origin: "https://evil.example")
    assert_app_served(origin: "https://evil.example")

    assert_equal 1, @log.string.scan("accepted a WebSocket connection from Origin \"https://evil.example\"").size
    assert_includes @log.string, "Set RUFLET_ALLOWED_ORIGINS"
  end

  def test_outside_ruflet_run_the_allowed_origins_argument_enforces
    start_server(allowed_origins: ["https://app.example.com"])

    assert_app_served(origin: "https://app.example.com")
    assert_app_served(origin: nil)
    runs_before = @handler_runs.size
    socket, status = handshake(origin: "https://evil.example")
    assert_equal "HTTP/1.1 403 Forbidden", status
    assert_equal runs_before, @handler_runs.size
  ensure
    socket&.close
  end

  private

  def start_server(**options)
    handler_runs = @handler_runs
    @server = Ruflet::Server.new(host: "127.0.0.1", port: 0, **options) do |page|
      button = Ruflet::UI::ControlFactory.build(:button, content: "Delete account")
      button.on(:click) { |_event| handler_runs << :delete_account }
      page.add(Ruflet::UI::ControlFactory.build(:text, value: SECRET))
      page.add(button)
    end
    @server_thread = Thread.new { @server.start }
    deadline = Time.now + 5
    sleep 0.01 until (@server.port.to_i.positive? && @server.instance_variable_get(:@running)) || Time.now > deadline
    assert @server.port.to_i.positive?, "server bound a port"
  end

  def handshake(origin:, host: nil, extra_headers: {})
    socket = TCPSocket.new("127.0.0.1", @server.port)
    lines = [
      "GET /ws HTTP/1.1",
      "Host: #{host || "127.0.0.1:#{@server.port}"}",
      "Upgrade: websocket",
      "Connection: Upgrade",
      "Sec-WebSocket-Key: #{[SecureRandom.random_bytes(16)].pack("m0")}",
      "Sec-WebSocket-Version: 13"
    ]
    lines << "Origin: #{origin}" if origin
    extra_headers.each { |key, value| lines << "#{key}: #{value}" }
    socket.write("#{lines.join("\r\n")}\r\n\r\n")
    status = socket.gets("\r\n").to_s.strip
    nil until [nil, "\r\n"].include?(socket.gets("\r\n"))
    [socket, status]
  end

  # Upgrades, registers, reads the page and clicks the button, like the
  # audit's probe; asserts the app served and the handler ran.
  def assert_app_served(origin:, host: nil, extra_headers: {})
    socket, status = handshake(origin: origin, host: host, extra_headers: extra_headers)
    assert_equal "HTTP/1.1 101 Switching Protocols", status, "Origin #{origin.inspect} is upgraded"

    socket.write(client_frame(Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:register_client],
      { "session_id" => "", "page_name" => "", "page" => { "route" => "/", "width" => 800, "height" => 600 } }
    ])))
    messages = read_messages(socket)
    dump = messages.inspect
    assert_includes dump, SECRET
    button_id = find_wire_id(messages, "Delete account")
    refute_nil button_id

    runs_before = @handler_runs.size
    socket.write(client_frame(Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:control_event],
      { "target" => button_id, "name" => "click", "data" => nil }
    ])))
    deadline = Time.now + 2
    sleep 0.01 while @handler_runs.size == runs_before && Time.now < deadline
    assert_equal runs_before + 1, @handler_runs.size, "the click reached the handler"
  ensure
    socket&.close
  end

  def client_frame(payload)
    mask = SecureRandom.random_bytes(4)
    length = payload.bytesize
    header = [0x82].pack("C")
    header << (length < 126 ? [0x80 | length].pack("C") : [0x80 | 126, length].pack("Cn"))
    masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask.getbyte(index % 4) }.pack("C*")
    header + mask + masked
  end

  def read_messages(socket, quiet: 0.3)
    messages = []
    while IO.select([socket], nil, nil, messages.empty? ? 2 : quiet)
      head = socket.read(2)
      break unless head && head.bytesize == 2

      length = head.getbyte(1) & 0x7f
      length = socket.read(2).unpack1("n") if length == 126
      length = socket.read(8).unpack1("Q>") if length == 127
      payload = length.zero? ? "".b : socket.read(length)
      messages << Ruflet::WireCodec.unpack(payload) if (head.getbyte(0) & 0x0f) == 2
    end
    messages
  end

  def find_wire_id(node, marker)
    case node
    when Hash
      return node["_i"] if node.values.any? { |value| value.to_s == marker }

      node.each_value do |value|
        found = find_wire_id(value, marker)
        return found if found
      end
      nil
    when Array
      node.each do |value|
        found = find_wire_id(value, marker)
        return found if found
      end
      nil
    end
  end
end
