# frozen_string_literal: true

require_relative "test_helper"

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

  def test_unpack_decodes_flet_message_pack_ext_values
    assert_equal "2026-05-20T12:30:00+00:00", Ruflet::WireCodec.unpack(ext8(1, "2026-05-20T12:30:00+00:00"))
    assert_equal "09:45", Ruflet::WireCodec.unpack(ext8(2, "09:45"))
    assert_equal 123_456, Ruflet::WireCodec.unpack(ext8(3, "123456"))
    assert_equal "js-value", Ruflet::WireCodec.unpack(ext8(4, "js-value"))
  end

  def test_pack_encodes_picker_dates_as_flet_message_pack_ext_values
    payload = {
      "_c" => "DatePicker",
      "value" => "2026-05-20",
      "first_date" => "2026-01-01",
      "last_date" => "2026-12-31"
    }

    encoded = Ruflet::WireCodec.pack(payload)

    assert_includes encoded, ext8(1, "2026-05-20T00:00:00+00:00")
    assert_includes encoded, ext8(1, "2026-01-01T00:00:00+00:00")
    assert_includes encoded, ext8(1, "2026-12-31T00:00:00+00:00")
  end

  def test_pack_encodes_time_picker_value_as_flet_message_pack_ext_value
    payload = { "_c" => "TimePicker", "value" => "09:30" }

    encoded = Ruflet::WireCodec.pack(payload)

    assert_includes encoded, ext8(2, "09:30")
  end

  private

  def ext8(type, payload)
    bytes = payload.b
    "\xc7".b + [bytes.bytesize, type].pack("Cc") + bytes
  end
end
