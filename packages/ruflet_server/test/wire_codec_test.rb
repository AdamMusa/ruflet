# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class RufletServerWireCodecTest < Minitest::Test
  def test_pack_unpack_round_trip_for_nested_payload
    payload = {
      "name" => "demo",
      "count" => 3,
      "active" => true,
      "items" => [1, "two", { "x" => 9 }]
    }

    encoded = Ruflet::WireCodec.pack(payload)
    decoded = Ruflet::WireCodec.unpack(encoded)

    assert_equal payload, decoded
  end

  def test_symbol_keys_are_stringified
    encoded = Ruflet::WireCodec.pack(status: :ok)
    decoded = Ruflet::WireCodec.unpack(encoded)

    assert_equal({ "status" => "ok" }, decoded)
  end

  def test_unpack_supports_bin16_marker
    bytes = ["c5 00 03 61 62 63".delete(" ")].pack("H*")
    decoded = Ruflet::WireCodec.unpack(bytes)

    assert_equal "abc".b, decoded
  end

  def test_pack_binary_string_uses_message_pack_bin_marker
    encoded = Ruflet::WireCodec.pack("\xff\x00".b)

    assert_equal 0xc4, encoded.getbyte(0)
  end

  def test_flet_date_and_time_extensions_round_trip_with_their_types
    date = Ruflet::Protocol.date_time("2026-05-21T00:00:00+00:00")
    time = Ruflet::Protocol.time_of_day("9:30")

    encoded = Ruflet::WireCodec.pack("date" => date, "time" => time)
    decoded = Ruflet::WireCodec.unpack(encoded)

    assert_equal 0xc7, Ruflet::WireCodec.pack(date).getbyte(0)
    assert_equal 1, Ruflet::WireCodec.pack(date).getbyte(2)
    assert_equal 2, Ruflet::WireCodec.pack(time).getbyte(2)
    assert_instance_of Ruflet::Protocol::DateTimeValue, decoded["date"]
    assert_instance_of Ruflet::Protocol::TimeOfDayValue, decoded["time"]
    assert_equal date, decoded["date"]
    assert_equal time, decoded["time"]
  end

  def test_summary_trace_prints_compact_timestamped_metadata
    message = [3, { "target" => 4, "name" => "change", "data" => { "value" => "Ruby" } }]
    encoded = Ruflet::WireCodec.pack(message)
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV["RUFLET_PROTOCOL_TRACE"] = "summary"

    output, = capture_io { Ruflet::WireCodec.trace("client->ruby", encoded) }

    assert_match(/\[RUFLET_PROTOCOL\] t=\d+\.\d+ client->ruby/, output)
    assert_includes output, "bytes=#{encoded.bytesize}"
    assert_includes output, "action=3"
    assert_includes output, "target=4"
    assert_includes output, 'name="change"'
    refute_includes output, "hex="
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end

  def test_full_trace_prints_exact_bytes_and_decoded_data
    message = [3, { "target" => 4, "name" => "change", "data" => { "value" => "Ruby" } }]
    encoded = Ruflet::WireCodec.pack(message)
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV["RUFLET_PROTOCOL_TRACE"] = "1"

    output, = capture_io { Ruflet::WireCodec.trace("client->ruby", encoded) }

    assert_includes output, "hex=#{encoded.unpack("H*").first}"
    assert_includes output, '"target" => 4'
    assert_includes output, '"value" => "Ruby"'
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end

  def test_trace_can_be_disabled
    encoded = Ruflet::WireCodec.pack([0, {}])
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV["RUFLET_PROTOCOL_TRACE"] = "0"

    output, = capture_io { Ruflet::WireCodec.trace("ruby->client", encoded) }

    assert_empty output
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end

  def test_trace_is_disabled_by_default
    encoded = Ruflet::WireCodec.pack([0, {}])
    previous = ENV["RUFLET_PROTOCOL_TRACE"]
    ENV.delete("RUFLET_PROTOCOL_TRACE")

    output, = capture_io { Ruflet::WireCodec.trace("ruby->client", encoded) }

    assert_empty output
  ensure
    ENV["RUFLET_PROTOCOL_TRACE"] = previous
  end
end
