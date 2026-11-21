# frozen_string_literal: true

require_relative "test_helper"

# Malformed MessagePack from a client must fail as a StandardError, which the
# connection loop logs, and must not allocate for sizes it does not contain.
# A SystemStackError is not a StandardError: it killed the connection thread
# with nothing logged.
class RufletWireCodecLimitsTest < Minitest::Test
  LIMIT = Ruflet::WireCodec::MAX_NESTING_DEPTH

  def test_arrays_nested_up_to_the_limit_decode
    value = in_connection_thread { Ruflet::WireCodec.unpack(nested_arrays(LIMIT)) }

    depth = 0
    while value.is_a?(Array)
      value = value.first
      depth += 1
    end
    assert_equal LIMIT, depth
  end

  def test_arrays_nested_past_the_limit_are_a_decode_error
    [LIMIT + 1, 10_000, 200_000].each do |depth|
      error = in_connection_thread do
        Ruflet::WireCodec.unpack(nested_arrays(depth))
        nil
      rescue StandardError => e
        e
      end

      assert_kind_of RuntimeError, error, "depth #{depth}"
      assert_match(/nests more than #{LIMIT}/, error.message)
    end
  end

  def test_maps_nested_past_the_limit_are_a_decode_error
    error = in_connection_thread do
      Ruflet::WireCodec.unpack(("\x81\xa1k".b * 50_000) + "\xc0".b)
      nil
    rescue StandardError => e
      e
    end

    assert_kind_of RuntimeError, error
  end

  def test_the_limit_leaves_room_for_every_walk_the_server_makes_over_a_decoded_event
    server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
    data = nil
    (LIMIT - 3).times { data = { "k" => data } }
    raw = Ruflet::WireCodec.pack([3, { "target" => 1, "name" => "click", "data" => data }])

    in_connection_thread do
      _action, payload = server.send(:decode_incoming, raw)
      event = Ruflet::Protocol.normalize_control_event_payload(payload)
      server.send(:normalize_event_data, event["data"]).inspect
    end
  end

  def test_a_count_larger_than_the_bytes_left_fails_before_allocating
    before = virtual_memory_kb
    skip "ps is unavailable" unless before

    error = assert_raises(RuntimeError) { Ruflet::WireCodec.unpack("\xdd\xff\xff\xff\xf0".b) }
    assert_equal "Unexpected EOF", error.message
    assert_raises(RuntimeError) { Ruflet::WireCodec.unpack("\xdf\x7f\xff\xff\xff".b) }

    # Array.new(4_294_967_280) reserved about 32 GB of address space.
    grown_gb = (virtual_memory_kb - before) / 1024.0 / 1024.0
    assert_operator grown_gb, :<, 4, "decoding a 5-byte message reserved #{grown_gb.round(1)} GB"
  end

  def test_short_arrays_and_maps_still_report_unexpected_eof
    error = assert_raises(RuntimeError) { Ruflet::WireCodec.unpack("\x93\x01\x02".b) }
    assert_equal "Unexpected EOF", error.message
    error = assert_raises(RuntimeError) { Ruflet::WireCodec.unpack("\x82\xa1a\x01".b) }
    assert_equal "Unexpected EOF", error.message
  end

  def test_the_server_traces_its_own_messages_whatever_their_depth
    value = nil
    (LIMIT + 10).times { value = [value] }
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV["RUFLET_PROTOCOL_TRACE"] = "1"

    output, = capture_io { Ruflet::WireCodec.trace("ruby->client conn=1", Ruflet::WireCodec.pack(value), max_depth: nil) }

    refute_includes output, "decode_error"
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end

  private

  def nested_arrays(depth)
    ("\x91".b * depth) + "\xc0".b
  end

  # Connection threads have a smaller stack than the main thread.
  def in_connection_thread(&block)
    Thread.new(&block).value
  end

  def virtual_memory_kb
    out = `ps -o vsz= -p #{Process.pid} 2>/dev/null`.strip
    out.empty? ? nil : out.to_i
  rescue StandardError
    nil
  end
end
