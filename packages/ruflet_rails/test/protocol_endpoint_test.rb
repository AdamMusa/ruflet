# frozen_string_literal: true

require_relative "test_helper"
require "socket"
require "digest/sha1"
require "stringio"

# End-to-end proof that a Flutter client's wire protocol flows through the
# Rails server socket (Rack hijack) into ruflet_core pages and back —
# using the exact bytes the unmodified Flutter client sends.
class RufletProtocolEndpointTest < Minitest::Test
  WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  def test_register_event_and_patch_round_trip_through_rack_hijack
    server_io, client_io = UNIXSocket.pair

    clicks = []
    runner = Ruflet::Rails::Protocol::Runner.new do |page|
      page.title = "Rails Adapter"
      button = Ruflet::UI::ControlFactory.build(:button, content: "Tap")
      button.on(:click) { |_event| clicks << :clicked }
      page.add(button)
    end
    endpoint = runner.build_endpoint(path: "/ws")

    env = hijack_env(server_io)
    status, _headers, _body = endpoint.call(env)
    assert_equal(-1, status, "endpoint should hijack the socket")

    handshake = read_http_response(client_io)
    assert_includes handshake, "101 Switching Protocols"
    expected_accept = [Digest::SHA1.digest("testkey#{WEBSOCKET_GUID}")].pack("m0")
    assert_includes handshake, "Sec-WebSocket-Accept: #{expected_accept}"

    # Register exactly like the Flutter client does.
    send_client_frame(client_io, Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:register_client],
      {
        "session_id" => "",
        "page_name" => "",
        "page" => { "route" => "/", "width" => 800, "height" => 600,
                    "platform" => "macos", "platform_brightness" => "light", "media" => {} }
      }
    ]))

    ack = Ruflet::WireCodec.unpack(read_server_frame(client_io))
    assert_equal Ruflet::Protocol::ACTIONS[:register_client], ack[0]
    session_id = ack[1]["session_id"]
    refute_empty session_id.to_s

    patch = Ruflet::WireCodec.unpack(read_server_frame(client_io))
    assert_equal Ruflet::Protocol::ACTIONS[:patch_control], patch[0]
    patch_text = patch[1].inspect
    assert_includes patch_text, "Rails Adapter"
    assert_includes patch_text, "Tap"

    # Fire the button's click event by wire id, like a real client tap.
    wire_id = find_wire_id(patch[1], "Tap")
    refute_nil wire_id, "button wire id should be present in the patch"
    send_client_frame(client_io, Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:control_event],
      { "target" => wire_id, "name" => "click", "data" => "" }
    ]))

    deadline = Time.now + 2
    sleep 0.02 while clicks.empty? && Time.now < deadline
    assert_equal [:clicked], clicks, "click handler should run inside the Rails adapter"

    # Session is registered in the Rails session registry.
    assert Ruflet::Rails.sessions[session_id], "session should be tracked in the registry"
  ensure
    client_io&.close rescue nil
    server_io&.close rescue nil
  end

  # A raising handler is logged and the session goes on, as under
  # `ruflet run`: no session_crashed, the socket stays open, the next event
  # reaches its handler and the registry keeps the session.
  def test_a_raising_event_handler_keeps_the_connection_and_the_session
    server_io, client_io = UNIXSocket.pair
    log = StringIO.new
    original_stderr = $stderr
    $stderr = log

    clicks = 0
    runner = Ruflet::Rails::Protocol::Runner.new do |page|
      label = Ruflet::UI::ControlFactory.build(:text, value: "count=0")
      button = Ruflet::UI::ControlFactory.build(:button, content: "Save")
      button.on(:click) do |_event|
        clicks += 1
        raise ArgumentError, "validation failed" if clicks == 1

        page.update(label, value: "count=#{clicks}")
      end
      page.add(label)
      page.add(button)
    end
    endpoint = runner.build_endpoint(path: "/ws")
    assert_equal(-1, endpoint.call(hijack_env(server_io))[0])
    read_http_response(client_io)

    send_client_frame(client_io, Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:register_client],
      { "session_id" => "", "page" => { "route" => "/" } }
    ]))
    session_id = Ruflet::WireCodec.unpack(read_server_frame(client_io))[1]["session_id"]
    wire_id = nil
    while wire_id.nil? && (frame = read_server_frame_within(client_io, 2))
      wire_id = find_wire_id(Ruflet::WireCodec.unpack(frame)[1], "Save")
    end
    refute_nil wire_id, "the page patch publishes the button"
    click = Ruflet::WireCodec.pack([
      Ruflet::Protocol::ACTIONS[:control_event],
      { "target" => wire_id, "name" => "click", "data" => "" }
    ])

    send_client_frame(client_io, click)
    send_client_frame(client_io, click)

    # Read until the second click's patch arrives (or the server gives up).
    replies = []
    until replies.any? { |action, payload| action == Ruflet::Protocol::ACTIONS[:patch_control] && payload.inspect.include?("count=2") }
      frame = read_server_frame_within(client_io, 2)
      break unless frame

      replies << Ruflet::WireCodec.unpack(frame)
    end

    refute_includes replies.map(&:first), Ruflet::Protocol::ACTIONS[:session_crashed], "a handler error must not crash the session"
    assert replies.any? { |_action, payload| payload.inspect.include?("count=2") }, "the second click's update reaches the client"
    assert_equal 2, clicks
    assert Ruflet::Rails.sessions[session_id], "the registry keeps the session"
    assert_includes log.string, "ArgumentError: validation failed", "the handler error is still logged"
  ensure
    $stderr = original_stderr if original_stderr
    client_io&.close rescue nil
    server_io&.close rescue nil
  end

  private

  # The next frame, or nil when none arrives in time or the server closed
  # the socket.
  def read_server_frame_within(io, seconds)
    return nil unless IO.select([io], nil, nil, seconds)

    read_server_frame(io)
  rescue RuntimeError, IOError, Errno::ECONNRESET
    nil
  end

  def hijack_env(io)
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/ws",
      "HTTP_UPGRADE" => "websocket",
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_SEC_WEBSOCKET_KEY" => "testkey",
      "HTTP_SEC_WEBSOCKET_VERSION" => "13",
      "rack.hijack" => lambda { },
      "rack.hijack_io" => io
    }
  end

  def read_http_response(io)
    response = +""
    response << io.readpartial(1024) until response.include?("\r\n\r\n")
    response
  end

  # Client->server frames are masked, exactly like a browser/Flutter client.
  def send_client_frame(io, payload)
    mask = [rand(256), rand(256), rand(256), rand(256)]
    header = [0x82].pack("C") # FIN + binary
    length = payload.bytesize
    header <<
      if length < 126
        [0x80 | length].pack("C")
      elsif length < 65_536
        [0x80 | 126, length].pack("Cn")
      else
        [0x80 | 127, length].pack("CQ>")
      end
    masked = payload.bytes.each_with_index.map { |byte, index| byte ^ mask[index % 4] }
    io.write(header + mask.pack("C4") + masked.pack("C*"))
  end

  def read_server_frame(io)
    first = io.read(2)
    raise "connection closed" unless first && first.bytesize == 2

    opcode = first.getbyte(0) & 0x0f
    length = first.getbyte(1) & 0x7f
    length = io.read(2).unpack1("n") if length == 126
    length = io.read(8).unpack1("Q>") if length == 127
    payload = length.zero? ? "".b : io.read(length)
    return read_server_frame(io) if opcode != 2 # skip non-binary frames

    payload
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
