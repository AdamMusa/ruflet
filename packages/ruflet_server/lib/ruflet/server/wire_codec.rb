# frozen_string_literal: true

module Ruflet
  class WireCodec
    class << self
      def pack(value)
        case value
        when NilClass
          "\xc0".b
        when TrueClass
          "\xc3".b
        when FalseClass
          "\xc2".b
        when Integer
          pack_integer(value)
        when Float
          "\xcb".b + [value].pack("G")
        when String
          pack_string(value)
        when Symbol
          pack_string(value.to_s)
        when Array
          pack_array(value)
        when Hash
          pack_map(value)
        else
          pack_string(value.to_s)
        end
      end

      def unpack(bytes)
        reader = ByteReader.new(bytes)
        read_value(reader)
      end

      private

      def pack_integer(value)
        if value >= 0
          return [value].pack("C") if value <= 0x7f
          return "\xcc".b + [value].pack("C") if value <= 0xff
          return "\xcd".b + [value].pack("n") if value <= 0xffff
          return "\xce".b + [value].pack("N") if value <= 0xffff_ffff

          "\xcf".b + [value].pack("Q>")
        else
          return [value & 0xff].pack("C") if value >= -32
          return "\xd0".b + [value].pack("c") if value >= -128
          return "\xd1".b + [value].pack("s>") if value >= -32_768
          return "\xd2".b + [value].pack("l>") if value >= -2_147_483_648

          "\xd3".b + [value].pack("q>")
        end
      end

      def pack_string(value)
        str = value.to_s.dup.force_encoding("UTF-8")
        bytes = str.b
        len = bytes.bytesize

        if len <= 31
          [0xA0 | len].pack("C") + bytes
        elsif len <= 0xff
          "\xd9".b + [len].pack("C") + bytes
        elsif len <= 0xffff
          "\xda".b + [len].pack("n") + bytes
        else
          "\xdb".b + [len].pack("N") + bytes
        end
      end

      def pack_array(value)
        len = value.length
        head =
          if len <= 15
            [0x90 | len].pack("C")
          elsif len <= 0xffff
            "\xdc".b + [len].pack("n")
          else
            "\xdd".b + [len].pack("N")
          end

        body = +"".b
        value.each { |item| body << pack(item) }
        head + body
      end

      def pack_map(value)
        pairs = value.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
        len = pairs.length
        head =
          if len <= 15
            [0x80 | len].pack("C")
          elsif len <= 0xffff
            "\xde".b + [len].pack("n")
          else
            "\xdf".b + [len].pack("N")
          end

        body = +"".b
        pairs.each do |k, v|
          body << pack(k)
          body << pack(v)
        end
        head + body
      end

      def read_value(reader)
        marker = reader.read_u8

        return marker if marker <= 0x7f
        return marker - 256 if marker >= 0xe0

        case marker
        when 0xc0 then nil
        when 0xc2 then false
        when 0xc3 then true
        when 0xcc then reader.read_u8
        when 0xcd then reader.read_u16
        when 0xce then reader.read_u32
        when 0xcf then reader.read_u64
        when 0xd0 then reader.read_i8
        when 0xd1 then reader.read_i16
        when 0xd2 then reader.read_i32
        when 0xd3 then reader.read_i64
        when 0xca then reader.read_f32
        when 0xcb then reader.read_f64
        when 0xd9 then reader.read_string(reader.read_u8)
        when 0xda then reader.read_string(reader.read_u16)
        when 0xdb then reader.read_string(reader.read_u32)
        when 0xdc then read_array(reader, reader.read_u16)
        when 0xdd then read_array(reader, reader.read_u32)
        when 0xde then read_map(reader, reader.read_u16)
        when 0xdf then read_map(reader, reader.read_u32)
        else
          if (marker & 0xf0) == 0x90
            read_array(reader, marker & 0x0f)
          elsif (marker & 0xf0) == 0x80
            read_map(reader, marker & 0x0f)
          elsif (marker & 0xe0) == 0xa0
            reader.read_string(marker & 0x1f)
          else
            raise "Unsupported MessagePack marker: 0x#{marker.to_s(16)}"
          end
        end
      end

      def read_array(reader, size)
        Array.new(size) { read_value(reader) }
      end

      def read_map(reader, size)
        out = {}
        size.times do
          key = read_value(reader)
          out[key.to_s] = read_value(reader)
        end
        out
      end
    end

    class ByteReader
      def initialize(bytes)
        @data = bytes.to_s.b
        @offset = 0
      end

      def read_u8
        value = @data.getbyte(@offset)
        raise "Unexpected EOF" if value.nil?

        @offset += 1
        value
      end

      def read_exact(size)
        chunk = @data.byteslice(@offset, size)
        raise "Unexpected EOF" if chunk.nil? || chunk.bytesize != size

        @offset += size
        chunk
      end

      def read_u16
        read_exact(2).unpack1("n")
      end

      def read_u32
        read_exact(4).unpack1("N")
      end

      def read_u64
        read_exact(8).unpack1("Q>")
      end

      def read_i8
        read_exact(1).unpack1("c")
      end

      def read_i16
        read_exact(2).unpack1("s>")
      end

      def read_i32
        read_exact(4).unpack1("l>")
      end

      def read_i64
        read_exact(8).unpack1("q>")
      end

      def read_f32
        read_exact(4).unpack1("g")
      end

      def read_f64
        read_exact(8).unpack1("G")
      end

      def read_string(size)
        read_exact(size).force_encoding("UTF-8")
      end
    end
  end
end
