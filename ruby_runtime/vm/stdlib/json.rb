# frozen_string_literal: true

# Minimal JSON module for the embedded VM: parse and generate for the JSON
# subset (objects, arrays, strings, numbers, booleans, null).
module JSON
  class ParserError < StandardError; end

  class << self
    def parse(source, _opts = nil)
      parser = Parser.new(source)
      value = parser.parse_value
      parser.skip_whitespace
      raise ParserError, "unexpected trailing data" unless parser.eof?

      value
    end

    def generate(value)
      dump_value(value)
    end
    alias dump generate

    private

    def dump_value(value)
      case value
      when nil then "null"
      when true then "true"
      when false then "false"
      when Integer, Float then value.to_s
      when String then dump_string(value)
      when Symbol then dump_string(value.to_s)
      when Array
        "[#{value.map { |item| dump_value(item) }.join(",")}]"
      when Hash
        pairs = value.map { |k, v| "#{dump_string(k.to_s)}:#{dump_value(v)}" }
        "{#{pairs.join(",")}}"
      else
        dump_string(value.to_s)
      end
    end

    def dump_string(text)
      out = +"\""
      text.each_char do |ch|
        case ch
        when "\"" then out << "\\\""
        when "\\" then out << "\\\\"
        when "\n" then out << "\\n"
        when "\r" then out << "\\r"
        when "\t" then out << "\\t"
        when "\b" then out << "\\b"
        when "\f" then out << "\\f"
        else
          if ch.ord < 0x20
            out << format("\\u%04x", ch.ord)
          else
            out << ch
          end
        end
      end
      out << "\""
      out
    end
  end

  class Parser
    def initialize(source)
      @source = source.to_s
      @index = 0
    end

    def eof?
      @index >= @source.length
    end

    def skip_whitespace
      @index += 1 while @index < @source.length && whitespace?(@source.getbyte(@index))
    end

    def parse_value
      skip_whitespace
      raise ParserError, "unexpected end of input" if eof?

      case current_char
      when "{" then parse_object
      when "[" then parse_array
      when "\"" then parse_string
      when "t" then expect_literal("true", true)
      when "f" then expect_literal("false", false)
      when "n" then expect_literal("null", nil)
      else parse_number
      end
    end

    private

    def current_char
      @source[@index]
    end

    def parse_object
      advance
      object = {}
      skip_whitespace
      return advance && object if current_char == "}"

      loop do
        skip_whitespace
        key = parse_string
        skip_whitespace
        expect_char(":")
        object[key] = parse_value
        skip_whitespace
        if current_char == "}"
          advance
          break
        end
        expect_char(",")
      end

      object
    end

    def parse_array
      advance
      array = []
      skip_whitespace
      return advance && array if current_char == "]"

      loop do
        array << parse_value
        skip_whitespace
        if current_char == "]"
          advance
          break
        end
        expect_char(",")
      end

      array
    end

    def parse_string
      expect_char("\"")
      out = +""

      until eof?
        char = current_char
        advance
        case char
        when "\""
          return out
        when "\\"
          raise ParserError, "unexpected end of input" if eof?

          escaped = current_char
          advance
          out << case escaped
                 when "\"", "\\", "/" then escaped
                 when "b" then "\b"
                 when "f" then "\f"
                 when "n" then "\n"
                 when "r" then "\r"
                 when "t" then "\t"
                 when "u" then parse_unicode_escape
                 else raise ParserError, "invalid escape sequence"
                 end
        else
          out << char
        end
      end

      raise ParserError, "unterminated string"
    end

    def parse_unicode_escape
      hex = @source[@index, 4]
      unless hex && hex.length == 4 && hex.each_char.all? { |c| ("0".."9").cover?(c) || ("a".."f").cover?(c) || ("A".."F").cover?(c) }
        raise ParserError, "invalid unicode escape"
      end

      @index += 4
      [hex.to_i(16)].pack("U")
    end

    def parse_number
      start = @index
      advance if current_char == "-"
      consume_digits
      if current_char == "."
        advance
        consume_digits
      end
      if current_char == "e" || current_char == "E"
        advance
        advance if current_char == "+" || current_char == "-"
        consume_digits
      end

      token = @source[start...@index]
      raise ParserError, "invalid number" if token.nil? || token.empty? || token == "-"

      token.include?(".") || token.include?("e") || token.include?("E") ? token.to_f : token.to_i
    end

    def consume_digits
      start = @index
      advance while !eof? && digit?(current_char)
      raise ParserError, "invalid number" if start == @index
    end

    def expect_literal(literal, value)
      if @source[@index, literal.length] == literal
        @index += literal.length
        value
      else
        raise ParserError, "unexpected token"
      end
    end

    def expect_char(char)
      raise ParserError, "expected #{char}" unless current_char == char

      advance
    end

    def whitespace?(byte)
      byte == 9 || byte == 10 || byte == 13 || byte == 32
    end

    def digit?(char)
      char >= "0" && char <= "9"
    end

    def advance
      @index += 1
    end
  end
end
