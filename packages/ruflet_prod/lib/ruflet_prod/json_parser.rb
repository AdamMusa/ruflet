# frozen_string_literal: true

module RufletProd
  module JsonParser
    def self.parse(source)
      parser = Parser.new(source)
      value = parser.parse_value
      parser.skip_ws
      raise "Trailing JSON content" unless parser.eof?

      value
    end

    class Parser
      def initialize(source)
        @s = source.to_s
        @i = 0
      end

      def eof?
        @i >= @s.length
      end

      def skip_ws
        @i += 1 while !eof? && @s.getbyte(@i) <= 0x20
      end

      def parse_value
        skip_ws
        raise "Unexpected EOF" if eof?

        ch = @s.getbyte(@i)
        case ch
        when 0x7B then parse_object
        when 0x5B then parse_array
        when 0x22 then parse_string
        when 0x74 then parse_true
        when 0x66 then parse_false
        when 0x6E then parse_null
        else
          parse_number
        end
      end

      private

      def parse_object
        expect_byte(0x7B)
        skip_ws
        out = {}
        if peek_byte == 0x7D
          @i += 1
          return out
        end

        loop do
          key = parse_string
          skip_ws
          expect_byte(0x3A)
          out[key] = parse_value
          skip_ws
          break if consume_if(0x7D)

          expect_byte(0x2C)
        end
        out
      end

      def parse_array
        expect_byte(0x5B)
        skip_ws
        out = []
        if peek_byte == 0x5D
          @i += 1
          return out
        end

        loop do
          out << parse_value
          skip_ws
          break if consume_if(0x5D)

          expect_byte(0x2C)
        end
        out
      end

      def parse_string
        expect_byte(0x22)
        out = "".dup

        until eof?
          ch = @s.getbyte(@i)
          @i += 1
          case ch
          when 0x22
            return out
          when 0x5C
            esc = @s.getbyte(@i)
            @i += 1
            case esc
            when 0x22 then out += "\""
            when 0x5C then out += "\\"
            when 0x2F then out += "/"
            when 0x62 then out += "\b"
            when 0x66 then out += "\f"
            when 0x6E then out += "\n"
            when 0x72 then out += "\r"
            when 0x74 then out += "\t"
            when 0x75
              hex = @s[@i, 4]
              raise "Invalid unicode escape" unless valid_hex4?(hex)

              # Keep escaped form to avoid runtime dependency on Array#pack in mruby.
              out += "\\u" + hex
              @i += 4
            else
              raise "Invalid escape sequence"
            end
          else
            out += @s[@i - 1, 1]
          end
        end

        raise "Unterminated string"
      end

      def parse_true
        expect_literal("true")
        true
      end

      def parse_false
        expect_literal("false")
        false
      end

      def parse_null
        expect_literal("null")
        nil
      end

      def parse_number
        start = @i
        @i += 1 if peek_byte == 0x2D

        if peek_byte == 0x30
          @i += 1
        else
          raise "Invalid number" unless digit?(peek_byte)

          @i += 1 while digit?(peek_byte)
        end

        if peek_byte == 0x2E
          @i += 1
          raise "Invalid number" unless digit?(peek_byte)
          @i += 1 while digit?(peek_byte)
        end

        if peek_byte == 0x65 || peek_byte == 0x45
          @i += 1
          @i += 1 if peek_byte == 0x2B || peek_byte == 0x2D
          raise "Invalid number" unless digit?(peek_byte)
          @i += 1 while digit?(peek_byte)
        end

        token = @s[start...@i]
        token.include?(".") || token.include?("e") || token.include?("E") ? token.to_f : token.to_i
      end

      def expect_literal(str)
        raise "Invalid token" unless @s[@i, str.length] == str

        @i += str.length
      end

      def expect_byte(byte)
        skip_ws
        raise "Unexpected EOF" if eof?
        raise "Unexpected token" unless @s.getbyte(@i) == byte

        @i += 1
      end

      def consume_if(byte)
        skip_ws
        return false if eof? || @s.getbyte(@i) != byte

        @i += 1
        true
      end

      def peek_byte
        eof? ? nil : @s.getbyte(@i)
      end

      def digit?(byte)
        !byte.nil? && byte >= 0x30 && byte <= 0x39
      end

      def hex_digit?(byte)
        return false if byte.nil?

        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x46) || (byte >= 0x61 && byte <= 0x66)
      end

      def valid_hex4?(str)
        return false unless str && str.length == 4

        i = 0
        while i < 4
          return false unless hex_digit?(str.getbyte(i))

          i += 1
        end
        true
      end
    end
  end
end
