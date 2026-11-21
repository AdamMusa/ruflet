# frozen_string_literal: true

require_relative "test_helper"

# Every MessagePack format Ruflet::WireCodec writes or reads, at each size
# boundary: the marker byte the spec assigns, a round trip that keeps the
# value and its type, and (when the msgpack gem is installed) agreement with
# an independent MessagePack implementation in both directions.
class WireCodecContractTest < Minitest::Test
  begin
    require "msgpack"
    REFERENCE = true
  rescue LoadError
    REFERENCE = false
  end

  utf8 = ->(size) { ("é" * (size / 2)) + ("a" * (size % 2)) }
  bin = ->(size) { ("\x01" * size).b }

  # [label, value, marker byte]
  FORMATS = [
    ["nil", nil, 0xc0],
    ["false", false, 0xc2],
    ["true", true, 0xc3],
    ["positive fixint 0", 0, 0x00],
    ["positive fixint 127", 127, 0x7f],
    ["uint8 128", 128, 0xcc],
    ["uint8 255", 255, 0xcc],
    ["uint16 256", 256, 0xcd],
    ["uint16 65535", 65_535, 0xcd],
    ["uint32 65536", 65_536, 0xce],
    ["uint32 max", 0xffff_ffff, 0xce],
    ["uint64 2**32", 0x1_0000_0000, 0xcf],
    ["uint64 max", 0xffff_ffff_ffff_ffff, 0xcf],
    ["negative fixint -1", -1, 0xff],
    ["negative fixint -32", -32, 0xe0],
    ["int8 -33", -33, 0xd0],
    ["int8 -128", -128, 0xd0],
    ["int16 -129", -129, 0xd1],
    ["int16 min", -32_768, 0xd1],
    ["int32 -32769", -32_769, 0xd2],
    ["int32 min", -2_147_483_648, 0xd2],
    ["int64 -2**31-1", -2_147_483_649, 0xd3],
    ["int64 min", -(2**63), 0xd3],
    ["float64", 1.25, 0xcb],
    ["float64 negative", -0.5, 0xcb],
    ["fixstr empty", "", 0xa0],
    ["fixstr 31 bytes", utf8.call(31), 0xbf],
    ["str8 32 bytes", utf8.call(32), 0xd9],
    ["str8 255 bytes", utf8.call(255), 0xd9],
    ["str16 256 bytes", utf8.call(256), 0xda],
    ["str16 65535 bytes", utf8.call(65_535), 0xda],
    ["str32 65536 bytes", utf8.call(65_536), 0xdb],
    ["bin8 empty", bin.call(0), 0xc4],
    ["bin8 255", bin.call(255), 0xc4],
    ["bin16 256", bin.call(256), 0xc5],
    ["bin16 65535", bin.call(65_535), 0xc5],
    ["bin32 65536", bin.call(65_536), 0xc6],
    ["fixarray empty", [], 0x90],
    ["fixarray 15", Array.new(15) { |i| i }, 0x9f],
    ["array16 16", Array.new(16) { |i| i }, 0xdc],
    ["array16 65535", Array.new(65_535, 0), 0xdc],
    ["array32 65536", Array.new(65_536, 0), 0xdd],
    ["fixmap empty", {}, 0x80],
    ["fixmap 15", (1..15).to_h { |i| ["k#{i}", i] }, 0x8f],
    ["map16 16", (1..16).to_h { |i| ["k#{i}", i] }, 0xde],
    ["map16 65535", (1..65_535).to_h { |i| ["k#{i}", nil] }, 0xde],
    ["map32 65536", (1..65_536).to_h { |i| ["k#{i}", nil] }, 0xdf],
    ["nested", { "a" => [1, { "b" => "c" }, nil], "d" => true }, 0x82]
  ].freeze

  # Flet's extension types: 1 DateTime, 2 TimeOfDay, 3 Duration.
  EXTENSIONS = [
    [:date_time, 1, Ruflet::Protocol::DateTimeValue],
    [:time_of_day, 2, Ruflet::Protocol::TimeOfDayValue],
    [:duration, 3, Ruflet::Protocol::DurationValue]
  ].freeze

  # The writer always uses ext8/16/32 (valid for any payload size).
  EXT_WRITE_SIZES = { 1 => 0xc7, 19 => 0xc7, 255 => 0xc7, 256 => 0xc8, 65_535 => 0xc8, 65_536 => 0xc9 }.freeze
  # The reader also takes the fixext forms other encoders use for these sizes.
  FIXEXT_MARKERS = { 1 => 0xd4, 2 => 0xd5, 4 => 0xd6, 8 => 0xd7, 16 => 0xd8 }.freeze

  FORMATS.each do |label, value, marker|
    name = label.tr(" *-", "___").delete("^a-z0-9_")

    define_method("test_#{name}_uses_marker_#{format("%02x", marker)}_and_round_trips") do
      bytes = Ruflet::WireCodec.pack(value)

      assert_equal marker, bytes.getbyte(0), "#{label} marker"
      decoded = Ruflet::WireCodec.unpack(bytes)
      value.nil? ? assert_nil(decoded) : assert_equal(value, decoded)
      assert_equal Encoding::BINARY, decoded.encoding if value.is_a?(String) && value.encoding == Encoding::BINARY
    end

    define_method("test_#{name}_agrees_with_the_msgpack_gem") do
      skip "the msgpack gem is not installed" unless REFERENCE

      if value.nil?
        assert_nil MessagePack.unpack(Ruflet::WireCodec.pack(value))
        assert_nil Ruflet::WireCodec.unpack(MessagePack.pack(value))
      else
        assert_equal value, MessagePack.unpack(Ruflet::WireCodec.pack(value))
        assert_equal value, Ruflet::WireCodec.unpack(MessagePack.pack(value))
      end
    end
  end

  def test_symbols_pack_as_strings_and_map_keys_as_strings
    assert_equal "go", Ruflet::WireCodec.unpack(Ruflet::WireCodec.pack(:go))
    assert_equal({ "a" => 1, "2" => 2 }, Ruflet::WireCodec.unpack(Ruflet::WireCodec.pack({ a: 1, 2 => 2 })))
  end

  def test_float32_is_read
    assert_in_delta 1.5, Ruflet::WireCodec.unpack("\xca".b + [1.5].pack("g")), 0.0001
  end

  def test_other_objects_pack_as_their_string
    object = Object.new
    def object.to_s = "custom"

    assert_equal "custom", Ruflet::WireCodec.unpack(Ruflet::WireCodec.pack(object))
  end

  def test_invalid_utf8_strings_go_out_as_binary
    bytes = Ruflet::WireCodec.pack("\xff\xfe".dup.force_encoding("UTF-8"))

    assert_equal 0xc4, bytes.getbyte(0)
  end

  EXTENSIONS.each do |helper, type, klass|
    EXT_WRITE_SIZES.each do |size, marker|
      define_method("test_#{helper}_extension_of_#{size}_bytes_uses_marker_#{format("%02x", marker)}") do
        value = Ruflet::Protocol.public_send(helper, "1" * size)
        bytes = Ruflet::WireCodec.pack(value)

        assert_equal marker, bytes.getbyte(0)
        decoded = Ruflet::WireCodec.unpack(bytes)
        assert_instance_of klass, decoded
        assert_equal value, decoded
        next unless REFERENCE

        reference = MessagePack.unpack(bytes, allow_unknown_ext: true)
        assert_equal type, reference.type
        assert_equal "1" * size, reference.payload
      end
    end

    FIXEXT_MARKERS.each do |size, marker|
      define_method("test_#{helper}_extension_is_read_from_fixext_#{size}") do
        bytes = [marker, type].pack("Cc") + ("1" * size)
        assert_equal bytes, MessagePack.pack(MessagePack::ExtensionValue.new(type, "1" * size)) if REFERENCE

        decoded = Ruflet::WireCodec.unpack(bytes)
        assert_instance_of klass, decoded
        assert_equal "1" * size, decoded
      end
    end
  end
end
