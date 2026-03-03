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
end
