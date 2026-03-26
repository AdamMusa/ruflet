#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

ROOT = Pathname(__dir__).join("..").expand_path
GENERATED_RB = ROOT.join("generated/embedded_ruflet_runtime.rb")
GENERATED_H = ROOT.join("generated/embedded_ruflet_runtime.h")

BUNDLED_FEATURES = {
  "ruflet" => ROOT.join("packages/ruflet_core/lib/ruflet.rb"),
  "ruflet_core" => ROOT.join("packages/ruflet_core/lib/ruflet_core.rb"),
  "ruflet_protocol" => ROOT.join("packages/ruflet_core/lib/ruflet_protocol.rb"),
  "ruflet_ui" => ROOT.join("packages/ruflet_core/lib/ruflet_ui.rb"),
  "ruflet_server" => ROOT.join("packages/ruflet_server/lib/ruflet_server.rb")
}.freeze

BOOTSTRAP_FILES = [
  ROOT.join("packages/ruflet_core/lib/ruflet_protocol/ruflet/protocol.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/colors.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/icon_data.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/icons/material/material_icons.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/icons/cupertino/cupertino_icons.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/types/text_style.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/types/geometry.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/control.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/controls/ruflet_controls.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/services/ruflet_services.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/material_control_registry.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/cupertino_control_registry.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/material_control_methods.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/cupertino_control_methods.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/control_methods.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/control_factory.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/widget_builder.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/shared_control_forwarders.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/control_registry.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/event.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/page.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/app.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/dsl.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_ui.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet_core.rb"),
  ROOT.join("packages/ruflet_core/lib/ruflet.rb")
].freeze

EXTRA_SHIMS = <<~'RUBY'

  # -- Embedded stdlib compatibility
  module JSON
    class ParserError < StandardError; end

    class << self
      def parse(source)
        parser = Parser.new(source)
        value = parser.parse_value
        parser.skip_whitespace
        raise ParserError, "unexpected trailing data" unless parser.eof?

        value
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
        when "{"
          parse_object
        when "["
          parse_array
        when "\""
          parse_string
        when "t"
          expect_literal("true", true)
        when "f"
          expect_literal("false", false)
        when "n"
          expect_literal("null", nil)
        else
          parse_number
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
                   when "\"", "\\", "/"
                     escaped
                   when "b"
                     "\b"
                   when "f"
                     "\f"
                   when "n"
                     "\n"
                   when "r"
                     "\r"
                   when "t"
                     "\t"
                   when "u"
                     parse_unicode_escape
                   else
                     raise ParserError, "invalid escape sequence"
                   end
          else
            out << char
          end
        end

        raise ParserError, "unterminated string"
      end

      def parse_unicode_escape
        hex = @source[@index, 4]
        raise ParserError, "invalid unicode escape" unless hex && hex.length == 4 && hex.match?(/\A[0-9a-fA-F]{4}\z/)

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
        raise ParserError, "expected \#{char}" unless current_char == char

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

  class Array
    unless method_defined?(:dup)
      def dup
        self.class.new(self)
      end
    end

    unless method_defined?(:each_slice)
      def each_slice(size)
        index = 0
        while index < length
          yield(self[index, size])
          index += size
        end
        self
      end
    end

    unless method_defined?(:filter_map)
      def filter_map
        out = []
        each do |value|
          mapped = yield(value)
          out << mapped unless mapped.nil?
        end
        out
      end
    end
  end

  class Hash
    unless method_defined?(:dup)
      def dup
        out = {}
        each { |key, value| out[key] = value }
        out
      end
    end

    unless method_defined?(:filter_map)
      def filter_map
        out = []
        each do |key, value|
          mapped = yield(key, value)
          out << mapped unless mapped.nil?
        end
        out
      end
    end
  end

  class Integer
    unless method_defined?(:negative?)
      def negative?
        self < 0
      end
    end

    unless method_defined?(:zero?)
      def zero?
        self == 0
      end
    end
  end

  class String
    unless method_defined?(:%)
      def %(values)
        queue = values.is_a?(::Array) ? values.dup : [values]
        gsub(/%0?\d*[sdxX]/) do |token|
          value = queue.shift
          width = token[/\d+/].to_i
          case token[-1]
          when "s", "d"
            text = value.to_s
            width > 0 ? text.rjust(width, "0") : text
          when "x", "X"
            text = value.to_i.to_s(16)
            text = text.upcase if token[-1] == "X"
            if width > 0
              pad = "0" * [width - text.length, 0].max
              text = pad + text
            end
            text
          else
            value.to_s
          end
        end
      end
    end

    unless method_defined?(:+@)
      def +@
        self
      end
    end

    unless method_defined?(:<<)
      def <<(other)
        chunk =
          if other.is_a?(Integer)
            [other & 0xff].pack("C")
          else
            other.to_s
          end
        if respond_to?(:replace)
          replace(self + chunk)
        else
          self + chunk
        end
      end
    end

    unless method_defined?(:delete)
      def delete(*patterns)
        return dup if patterns.nil? || patterns.empty?

        removals = {}
        patterns.each do |pattern|
          pattern.to_s.each_byte { |byte| removals[byte] = true }
        end

        out = +""
        each_byte do |byte|
          out << byte unless removals[byte]
        end
        out
      end
    end

    unless method_defined?(:b)
      def b
        self
      end
    end

    unless method_defined?(:byteslice)
      def byteslice(start, length = nil)
        length.nil? ? self[start..-1] : self[start, length]
      end
    end

    unless method_defined?(:force_encoding)
      def force_encoding(_encoding)
        self
      end
    end

    unless method_defined?(:unpack1)
      def unpack1(format)
        unpack(format).first
      end
    end
  end

  module Enumerable
    unless method_defined?(:count)
      def count(item = nil, &block)
        total = 0

        if block
          each { |value| total += 1 if block.call(value) }
        elsif !item.nil?
          each { |value| total += 1 if value == item }
        else
          each { total += 1 }
        end

        total
      end
    end

    unless method_defined?(:to_set)
      def to_set
        set = Set.new
        each { |value| set << value }
        set
      end
    end
  end

  module Kernel
    has_rand_singleton =
      begin
        singleton_methods.include?(:rand)
      rescue StandardError
        false
      end

    unless has_rand_singleton
      @__ruflet_rand_state__ = 0x1234abcd

      def self.rand(arg = nil)
        @__ruflet_rand_state__ = ((@__ruflet_rand_state__ * 1_103_515_245) + 12_345) & 0x7fff_ffff
        value = @__ruflet_rand_state__
        return value if arg.nil?

        if arg.is_a?(Range)
          first = arg.begin.to_i
          last = arg.end.to_i
          span = last - first + (arg.exclude_end? ? 0 : 1)
          return first if span <= 1

          first + (value % span)
        else
          limit = arg.to_i
          return 0 if limit <= 0

          value % limit
        end
      end
    end

    unless method_defined?(:rand)
      def rand(arg = nil)
        Kernel.rand(arg)
      end

      private :rand
    end

    unless method_defined?(:Array)
      def Array(value)
        return [] if value.nil?
        return value if value.is_a?(::Array)
        return value.to_a if value.respond_to?(:to_a)

        [value]
      end

      private :Array
    end

    unless method_defined?(:require_relative)
      def require_relative(_feature)
        true
      end
    end

    unless method_defined?(:at_exit)
      def at_exit(&block)
        block
      end
    end
  end

  class Module
    unless method_defined?(:require_relative)
      def require_relative(_feature)
        true
      end
    end

    unless method_defined?(:trap)
      def trap(_signal_name, handler = nil, &block)
        handler || block
      end
    end
  end

  unless Object.const_defined?(:Encoding)
    module Encoding
      BINARY = "BINARY"
      UTF_8 = "UTF-8"
    end
  end

  unless Object.const_defined?(:SecureRandom)
    module SecureRandom
      module_function

      def hex(length = 16)
        RufletEmbeddedRuntime.random_hex(length.to_i * 2)
      end
    end
  end

  unless Object.const_defined?(:ENV)
    ENV = {}
  end

  unless Object.const_defined?(:Mutex)
    class Mutex
      def synchronize
        yield
      end
    end
  end

  unless Object.const_defined?(:Interrupt)
    class Interrupt < StandardError
    end
  end

  unless Object.const_defined?(:Thread)
    class Thread
      def self.new(*args, &block)
        block.call(*args) if block
        current
      end

      def self.current
        @current ||= allocate
      end

      def self.main
        current
      end

      def report_on_exception=(_value)
      end

      def raise(error = ::Interrupt)
        Kernel.raise(error)
      end
    end
  end

  unless Object.const_defined?(:Process)
    module Process
    end
  end

  module Process
    CLOCK_REALTIME = :clock_realtime unless const_defined?(:CLOCK_REALTIME)

    unless respond_to?(:clock_gettime)
      def self.clock_gettime(_clock_id, unit = nil)
        seed = Kernel.rand(0..0x7fff_ffff)
        return seed unless unit == :nanosecond

        (seed * 1_000_000).to_i + Kernel.rand(0..999_999)
      end
    end
  end

  unless Object.const_defined?(:CGI)
    module CGI
      extend self

      def escape(text)
        RufletEmbeddedRuntime.percent_encode(text)
      end
    end
  end

  unless Object.const_defined?(:Signal)
    module Signal
      module_function

      def trap(_signal_name, handler = nil, &block)
        handler || block
      end
    end
  end

  unless Object.const_defined?(:Digest)
    module Digest
    end
  end

  module RufletEmbeddedRuntime
    def sha1_digest(data)
      bytes = data.to_s.bytes
      bit_length = bytes.length * 8
      bytes << 0x80
      bytes << 0x00 while (bytes.length % 64) != 56
      8.times do |i|
        shift = (7 - i) * 8
        bytes << ((bit_length >> shift) & 0xff)
      end

      h0 = 0x67452301
      h1 = -271733879
      h2 = -1732584194
      h3 = 0x10325476
      h4 = -1009589776

      bytes.each_slice(64) do |chunk|
        words = Array.new(80, 0)
        16.times do |i|
          j = i * 4
          words[i] = word_from_bytes(chunk[j], chunk[j + 1], chunk[j + 2], chunk[j + 3])
        end

        16.upto(79) do |i|
          words[i] = left_rotate(xor32(words[i - 3], words[i - 8], words[i - 14], words[i - 16]), 1)
        end

        a = h0
        b = h1
        c = h2
        d = h3
        e = h4

        80.times do |i|
          if i < 20
            f = or32(and32(b, c), and32(not32(b), d))
            k = 0x5A827999
          elsif i < 40
            f = xor32(b, c, d)
            k = 0x6ED9EBA1
          elsif i < 60
            f = or32(and32(b, c), and32(b, d), and32(c, d))
            k = -1894007588
          else
            f = xor32(b, c, d)
            k = -899497514
          end

          temp = add32(left_rotate(a, 5), f, e, k, words[i])
          e = d
          d = c
          c = left_rotate(b, 30)
          b = a
          a = temp
        end

        h0 = add32(h0, a)
        h1 = add32(h1, b)
        h2 = add32(h2, c)
        h3 = add32(h3, d)
        h4 = add32(h4, e)
      end

      parts = []
      [h0, h1, h2, h3, h4].each do |word|
        hi, lo = split32(word)
        parts << [hi / 256, hi % 256, lo / 256, lo % 256].pack("C4")
      end
      parts.join
    end

    def word_from_bytes(b0, b1, b2, b3)
      hi = b0 * 256 + b1
      lo = b2 * 256 + b3
      join32(hi, lo)
    end

    def split32(value)
      if value >= 0
        [value / 0x10000, value % 0x10000]
      else
        abs = -value
        abs_hi = abs / 0x10000
        abs_lo = abs % 0x10000
        if abs_lo == 0
          [0x10000 - abs_hi, 0]
        else
          [0xffff - abs_hi, 0x10000 - abs_lo]
        end
      end
    end

    def join32(hi, lo)
      if hi >= 0x8000
        -(((0x10000 - hi) * 0x10000) - lo)
      else
        hi * 0x10000 + lo
      end
    end

    def add32(*values)
      hi = 0
      lo = 0
      values.each do |value|
        value_hi, value_lo = split32(value)
        lo += value_lo
        hi += value_hi + (lo / 0x10000)
        lo %= 0x10000
        hi %= 0x10000
      end
      join32(hi, lo)
    end

    def xor32(*values)
      hi = 0
      lo = 0
      values.each do |value|
        value_hi, value_lo = split32(value)
        hi ^= value_hi
        lo ^= value_lo
      end
      join32(hi, lo)
    end

    def and32(a, b)
      a_hi, a_lo = split32(a)
      b_hi, b_lo = split32(b)
      join32(a_hi & b_hi, a_lo & b_lo)
    end

    def or32(*values)
      hi = 0
      lo = 0
      values.each do |value|
        value_hi, value_lo = split32(value)
        hi |= value_hi
        lo |= value_lo
      end
      join32(hi, lo)
    end

    def not32(value)
      hi, lo = split32(value)
      join32(0xffff ^ hi, 0xffff ^ lo)
    end

    def left_rotate(value, bits)
      hi, lo = split32(value)
      bits.times do
        carry = (hi & 0x8000) != 0 ? 1 : 0
        hi = ((hi << 1) & 0xffff) | ((lo & 0x8000) >> 15)
        lo = ((lo << 1) & 0xffff) | carry
      end
      join32(hi, lo)
    end
  end

  unless Object.const_defined?(:Digest) &&
         Digest.const_defined?(:SHA1) &&
         Digest::SHA1.respond_to?(:digest)
    module Digest
      module SHA1
        extend self

        def digest(data)
          RufletEmbeddedRuntime.sha1_digest(data)
        end
      end
    end
  end
RUBY

def build_embedded_helper_forwarders
  source = ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/ui/shared_control_forwarders.rb").read
  method_lines = source.lines.grep(/^\s*def\s+/).reject { |line| line.include?("control_delegate") }
  method_lines.map do |line|
    line.sub("control_delegate.", "Ruflet::WidgetBuilder.new.")
  end.join
end

EMBEDDED_HELPER_FORWARDERS = build_embedded_helper_forwarders.freeze

POSTAMBLE = <<~RUBY
  class << Ruflet::UI::ControlFactory
    def build(type, id: nil, **props)
      normalized_type = type.to_s.downcase
      if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
        Kernel.warn("[embedded factory] type=\#{normalized_type} id=\#{id.inspect} props=\#{props.inspect}")
      end
      klass = Ruflet::UI::ControlFactory::CLASS_MAP[normalized_type]
      if klass
        normalized_props = normalize_constructor_props(klass, props)
        if ENV["RUFLET_DEBUG"] == "1" && normalized_type == "floatingactionbutton"
          Kernel.warn("[embedded factory] normalized_props=\#{normalized_props.inspect}")
        end
        return klass.new(id: id, **normalized_props)
      end

      raise ArgumentError, "Unknown control type: \#{normalized_type}"
    end

    def normalize_constructor_props(klass, props)
      keywords = constructor_keywords(klass)
      mapped = props.each_with_object({}) { |(k, v), out| out[k.to_sym] = v }
      return mapped if keywords.empty?

      allowed = keywords.map(&:to_s)
      if mapped.key?("value") && !allowed.include?("value") && allowed.include?("text") && !mapped.key?("text")
        mapped["text"] = mapped.delete("value")
      end
      if mapped.key?(:value) && !allowed.include?("value") && allowed.include?("text") && !mapped.key?(:text)
        mapped[:text] = mapped.delete(:value)
      end
      mapped
    end

    def constructor_keywords(klass)
      klass.instance_method(:initialize).parameters
           .select { |kind, _| kind == :key || kind == :keyreq }
           .map { |_, name| name }
           .reject { |name| name == :id }
    rescue StandardError
      []
    end
  end

  class Ruflet::DSL::App
    def text(value = nil, **props)
      mapped = props.dup
      mapped[:value] = value unless value.nil?
      build_widget(:text, **mapped)
    end
  end

  class Ruflet::App
#{EMBEDDED_HELPER_FORWARDERS.lines.map { |line| "    #{line}" }.join}  end

  class Ruflet::App
    private

    def text(value = nil, **props)
      Ruflet::WidgetBuilder.new.text(value, **props)
    end
  end

  module Kernel
#{EMBEDDED_HELPER_FORWARDERS.lines.map { |line| "    #{line}" }.join}  end

  module Kernel
    private

    def text(value = nil, **props)
      Ruflet::WidgetBuilder.new.text(value, **props)
    end
  end

  class Ruflet::Page
    private

    def resolve_control(control_or_id)
      return control_or_id if control_or_id.respond_to?(:wire_id)

      text = control_or_id.to_s
      numeric = !text.empty?
      text.each_byte do |byte|
        if byte < 48 || byte > 57
          numeric = false
          break
        end
      end

      if numeric
        @wire_index[text.to_i]
      else
        @control_index[text]
      end
    end

    def dispatch_page_event(name:, data:)
      event_name = name.to_s
      normalized_name =
        if event_name[0, 3] == "on_"
          event_name[3, event_name.length - 3].to_s
        else
          event_name
        end

      handler = @page_event_handlers[normalized_name]
      return unless handler.respond_to?(:call)

      event = Event.new(name: event_name, target: 1, raw_data: data, page: self, control: nil)
      handler.call(event)
    end
  end

  class Ruflet::Control
    alias_method :__embedded_original_initialize, :initialize
    alias_method :__embedded_original_to_patch, :to_patch

    def initialize(**__args__)
      __embedded_original_initialize(**__args__)
      if ENV["RUFLET_DEBUG"] == "1" && type.to_s.end_with?("button")
        Kernel.warn("[embedded control init] type=\#{type} props=\#{@props.inspect} handlers=\#{@handlers.keys.inspect}")
      end
    end

    def to_patch
      patch = __embedded_original_to_patch
      if ENV["RUFLET_DEBUG"] == "1" && type.to_s.end_with?("button")
        Kernel.warn("[embedded control] type=\#{type} props=\#{props.keys.sort.inspect} patch=\#{patch.inspect}")
      end
      patch
    end

    private

    def normalized_event_name(event_name)
      name = event_name.to_s
      if name[0, 3] == "on_"
        name[3, name.length - 3].to_s
      else
        name
      end
    end
  end

  class Ruflet::WireCodec
    class << self
      def pack_integer(value)
        if value >= 0
          return [value].pack("C") if value <= 0x7f
          return __embedded_uint_bytes(0xcc, value, 1) if value <= 0xff
          return __embedded_uint_bytes(0xcd, value, 2) if value <= 0xffff
          tmp = value
          4.times { tmp /= 256 }
          return __embedded_uint_bytes(0xce, value, 4) if tmp.zero?
          return __embedded_uint_bytes(0xcf, value, 8)
        end

        return [value & 0xff].pack("C") if value >= -32
        return __embedded_uint_bytes(0xd0, value + 0x100, 1) if value >= -0x80
        if value >= -0x8000
          return __embedded_uint_bytes(0xd1, value + 0x1_0000, 2)
        end
        if value >= -0x8000_0000
          return __embedded_uint_bytes(0xd2, value + 0x1_0000_0000, 4)
        end

        __embedded_uint_bytes(0xd3, value + 0x1_0000_0000_0000_0000, 8)
      rescue RangeError => e
        if ENV["RUFLET_DEBUG"] == "1"
          Kernel.warn("[embedded wire] pack_integer overflow value=\#{value.inspect} class=\#{value.class}")
          Kernel.warn(e.backtrace.join("\\n")) if e.backtrace
        end
        raise e
      end

      private

      def __embedded_uint_bytes(prefix, value, width)
        hex = value.to_s(16)
        target_length = width * 2
        if hex.length < target_length
          hex = ("0" * (target_length - hex.length)) + hex
        elsif hex.length > target_length
          hex = hex[-target_length, target_length]
        end

        out = RufletEmbeddedRuntime.byte_string(prefix)
        index = 0
        while index < target_length
          out += RufletEmbeddedRuntime.byte_string(hex[index, 2].to_i(16))
          index += 2
        end
        out
      end
    end
  end

  module Ruflet
    module Protocol
      extend self

      unless respond_to?(:pack_message)
        def self.pack_message(action:, payload:)
          [action, payload]
        end
      end

      unless respond_to?(:normalize_register_payload)
        def self.normalize_register_payload(payload)
          page = payload["page"] || {}
          {
            "session_id" => payload["session_id"],
            "page_name" => payload["page_name"] || "",
            "route" => page["route"] || "/",
            "width" => page["width"],
            "height" => page["height"],
            "platform" => page["platform"],
            "platform_brightness" => page["platform_brightness"],
            "media" => page["media"] || {}
          }
        end
      end

      unless respond_to?(:normalize_control_event_payload)
        def self.normalize_control_event_payload(payload)
          {
            "target" => payload["target"] || payload["eventTarget"],
            "name" => payload["name"] || payload["eventName"],
            "data" => payload["data"] || payload["eventData"]
          }
        end
      end

      unless respond_to?(:normalize_update_control_payload)
        def self.normalize_update_control_payload(payload)
          {
            "id" => payload["id"] || payload["target"] || payload["eventTarget"],
            "props" => payload["props"].is_a?(Hash) ? payload["props"] : {}
          }
        end
      end

      unless respond_to?(:register_response)
        def self.register_response(session_id:)
          {
            "session_id" => session_id,
            "page_patch" => {},
            "error" => nil
          }
        end
      end
    end

    class WebSocketConnection
      def initialize(socket, initial_data = nil)
        @socket = socket
        @write_mutex = ::Mutex.new
        @initial_data = initial_data.to_s.b
      end

      private

      def read_frame
        header = read_exact(2)
        return nil if header.nil?

        b1 = header.getbyte(0)
        b2 = header.getbyte(1)
        masked = (b2 & 0x80) != 0
        payload_len = b2 & 0x7f

        if payload_len == 126
          ext = read_exact(2)
          return nil if ext.nil?
          payload_len = ext.unpack1("n")
        elsif payload_len == 127
          ext = read_exact(8)
          return nil if ext.nil?
          payload_len = ext.unpack1("Q>")
        end

        warn "[embedded ws] opcode=\#{b1 & 0x0f} masked=\#{masked} payload_len=\#{payload_len}" if ENV["RUFLET_DEBUG"] == "1"
        return nil if payload_len.negative? || payload_len > MAX_FRAME_PAYLOAD_BYTES

        masking_key = masked ? read_exact(4) : nil
        return nil if masked && masking_key.nil?
        payload = payload_len.zero? ? "".b : read_exact(payload_len)
        return nil if payload.nil?

        payload = unmask(payload, masking_key) if masked
        prefix = payload.bytes.first(12).map { |byte| byte.to_i.to_s }.join(" ")
        warn "[embedded ws] payload bytes=\#{payload.bytesize} prefix=\#{prefix}" if ENV["RUFLET_DEBUG"] == "1"
        { opcode: b1 & 0x0f, payload: payload }
      end

      private

      def read_exact(length)
        return nil unless length.is_a?(Integer)
        return nil if length.negative? || length > MAX_FRAME_PAYLOAD_BYTES

        chunk = +""
        chunk.force_encoding(Encoding::BINARY)

        unless @initial_data.nil? || @initial_data.empty?
          take = [length, @initial_data.bytesize].min
          chunk = chunk + @initial_data.byteslice(0, take).to_s
          @initial_data = @initial_data.byteslice(take, @initial_data.bytesize - take).to_s.b
        end

        while chunk.bytesize < length
          remaining = length - chunk.bytesize

          if @socket.respond_to?(:recv)
            part = @socket.recv(remaining)
            return nil if part.nil? || part.empty?
            chunk = chunk + part.to_s
          elsif @socket.respond_to?(:read)
            part = @socket.read(remaining)
            return nil if part.nil? || part.empty?
            chunk = chunk + part.to_s
          elsif @socket.respond_to?(:getbyte)
            byte = @socket.getbyte
            return nil if byte.nil?
            chunk = chunk + [byte].pack("C")
          else
            return nil
          end
        end

        chunk
      rescue EOFError, IOError, SystemCallError
        nil
      end

      def unmask(payload, mask)
        out = +""
        out.force_encoding(Encoding::BINARY)
        payload.bytes.each_with_index do |byte, idx|
          out = out + [(byte ^ mask.getbyte(idx % 4))].pack("C")
        end
        out
      end
    end

    class Server
      private

      def pseudo_uuid
        [
          RufletEmbeddedRuntime.random_hex(8),
          RufletEmbeddedRuntime.random_hex(4),
          RufletEmbeddedRuntime.random_hex(4),
          RufletEmbeddedRuntime.random_hex(4),
          RufletEmbeddedRuntime.random_hex(12)
        ].join("-")
      end

      def on_register_client(ws, payload)
        warn "[embedded server] on_register_client begin" if ENV["RUFLET_DEBUG"] == "1"
        normalized = Protocol.normalize_register_payload(payload)
        session_id = normalized["session_id"].to_s.empty? ? pseudo_uuid : normalized["session_id"]
        warn "[embedded server] session_id=\#{session_id}" if ENV["RUFLET_DEBUG"] == "1"

        page = Page.new(
          session_id: session_id,
          client_details: normalized,
          sender: lambda do |action, msg_payload|
            send_message(ws, action, msg_payload)
          end
        )
        warn "[embedded server] page created" if ENV["RUFLET_DEBUG"] == "1"

        page.title = "Ruflet App"

        @sessions_mutex.synchronize do
          @sessions[ws.session_key] = page
        end
        warn "[embedded server] session stored" if ENV["RUFLET_DEBUG"] == "1"

        initial_response = [
          Protocol::ACTIONS[:register_client],
          {
            "session_id" => session_id,
            "page_patch" => {},
            "error" => nil
          }
        ]
        ws.send_binary(Ruflet::WireCodec.pack(initial_response))
        warn "[embedded server] initial response sent" if ENV["RUFLET_DEBUG"] == "1"

        @app_block.call(page)
        warn "[embedded server] app block finished" if ENV["RUFLET_DEBUG"] == "1"
        page.update
        warn "[embedded server] page updated" if ENV["RUFLET_DEBUG"] == "1"
      rescue StandardError => e
        if ENV["RUFLET_DEBUG"] == "1"
          warn "[embedded server] on_register_client error class=\#{e.class} message=\#{e.message.inspect}"
          warn e.backtrace.join("\\n") if e.backtrace
        end
        send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message })
        raise
      end

      def handle_socket(socket)
        ws = nil
        begin
          warn "[embedded server] handle_socket begin" if ENV["RUFLET_DEBUG"] == "1"
          path, headers, initial_data = read_http_upgrade_request(socket)
          warn "[embedded server] request path=\#{path.inspect} leftover=\#{initial_data.to_s.bytesize}" if ENV["RUFLET_DEBUG"] == "1"
          return if path.nil?

          if websocket_upgrade_request?(path, headers)
            warn "[embedded server] websocket upgrade" if ENV["RUFLET_DEBUG"] == "1"
            send_handshake_response(socket, headers["sec-websocket-key"])
            ws = Ruflet::WebSocketConnection.new(socket, initial_data)
            warn "[embedded server] run_connection" if ENV["RUFLET_DEBUG"] == "1"
            run_connection(ws)
          else
            warn "[embedded server] http request" if ENV["RUFLET_DEBUG"] == "1"
            handle_http_request(socket, path)
          end
        rescue StandardError => e
          return if disconnect_error?(e)

          warn "server error: \#{e.class}: \#{e.message}"
          warn e.backtrace.join("\\n") if e.backtrace
          send_message(ws, Protocol::ACTIONS[:session_crashed], { "message" => e.message.to_s.dup.force_encoding("UTF-8") }) if ws
        ensure
          close_connection(ws)
        end
      end

      def read_http_upgrade_request(socket)
        data = +""
        data.force_encoding(Encoding::BINARY)

        until data.include?("\\r\\n\\r\\n")
          part =
            if socket.respond_to?(:recv)
              socket.recv(1024)
            elsif socket.respond_to?(:read)
              socket.read(1024)
            else
              nil
            end

          return [nil, {}, "".b] if part.nil? || part.empty?

          data = data + part.to_s
          warn "[embedded server] recv bytes=\#{part.bytesize} total=\#{data.bytesize}" if ENV["RUFLET_DEBUG"] == "1"
          raise "HTTP header too large" if data.bytesize > 65_536
        end

        header_text, rest = data.split("\\r\\n\\r\\n", 2)
        lines = header_text.to_s.split("\\r\\n")
        request_line = lines.shift.to_s
        return [nil, {}, rest.to_s.b] unless request_line.include?(" ")

        method, path, _version = request_line.strip.split(" ", 3)
        return [nil, {}, rest.to_s.b] unless method == "GET"
        return [nil, {}, rest.to_s.b] if path.to_s.empty?

        headers = {}
        lines.each do |line|
          key, value = line.split(":", 2)
          next if key.nil? || value.nil?

          headers[key.strip.downcase] = value.strip
        end

        [path, headers, rest.to_s.b]
      end
    end
  end

  module Kernel
    def require(feature)
      bundled_features = {
        "ruflet" => true,
        "ruflet_core" => true,
        "ruflet_ui" => true,
        "ruflet_protocol" => true,
        "ruflet_server" => true,
        "json" => true,
        "set" => true,
        "cgi" => true,
        "timeout" => true,
        "socket" => true,
        "thread" => true,
        "digest/sha1" => true,
        "securerandom" => true
      }
      return true if bundled_features[feature.to_s]
      raise LoadError, "cannot load such file -- \#{feature}"
    end
  end
RUBY

def legacy_preamble
  content = GENERATED_RB.read
  idx = content.index("# -- Embedded stdlib compatibility")
  unless idx
    idx = content.index("# -- packages/")
  end
  raise "Unable to locate embedded runtime preamble marker" unless idx

  preamble = content[0...idx]
  preamble.rstrip + "\n"
end

def resolve_require_relative(base_file, relative_path)
  candidate = base_file.dirname.join(relative_path)
  candidate = candidate.sub_ext(".rb") if candidate.extname.empty?
  candidate
end

def bundled_require_path(feature)
  BUNDLED_FEATURES[feature]
end

def strip_source_lines(path, content, ordered_paths, seen)
  body = []

  content.each_line do |line|
    if line.start_with?("# frozen_string_literal:")
      next
    elsif (match = line.match(/^require_relative\s+["']([^"']+)["']/))
      dep = resolve_require_relative(path, match[1])
      process_file(dep, ordered_paths, seen)
      next
    elsif (match = line.match(/^require\s+["']([^"']+)["']/))
      dep = bundled_require_path(match[1])
      process_file(dep, ordered_paths, seen) if dep
      next
    end

    body << line
  end

  transform_source(path, body.join.rstrip + "\n")
end

def embedded_icon_map_literal(path)
  entries = JSON.parse(path.read)
  normalized = entries.each_with_object({}) do |(key, value), out|
    out[key.to_s.upcase] = value.to_i
  end
  normalized.inspect
end

def transform_icon_lookup_source(path, source)
  source = source.sub(/^\s*module_function\s*$/, "    extend self")
  icon_map_literal =
    if path.basename.to_s == "material_icon_lookup.rb"
      embedded_icon_map_literal(ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/icons/material/icons.json"))
    else
      embedded_icon_map_literal(ROOT.join("packages/ruflet_core/lib/ruflet_ui/ruflet/icons/cupertino/cupertino_icons.json"))
    end

  source = source.gsub(/^\s*LOCAL_ICONS_JSON = .*?\n/, "")
  source = source.gsub(
    /^(\s*)def load_icon_map\n.*?^\1end\n/m,
    "\\1def load_icon_map\n\\1  #{icon_map_literal}\n\\1end\n"
  )
  source = source.gsub(
    /^(\s*)def parse_icons_json\(path\)\n.*?^\1end\n/m,
    "\\1def parse_icons_json(_path)\n\\1  load_icon_map\n\\1end\n"
  )
  source
end

def transform_icon_constants_source(source)
  source = source.gsub(
    'text = name.to_s.gsub(/[^a-zA-Z0-9]/, "_").gsub(/_+/, "_").sub(/\A_/, "").sub(/_\z/, "")',
    'text = RufletEmbeddedRuntime.sanitize_const_name(name)'
  )
  source = source.gsub(
    'text = "ICON_#{text}" if text.match?(/\A\d/)',
    'text = "ICON_#{text}" if RufletEmbeddedRuntime.starts_with_digit?(text)'
  )
  source
end

def transform_instance_method_constant_source(source)
  names = source.scan(/^\s*def\s+([a-zA-Z_]\w*[!?=]?)/).flatten.uniq
  match = source.match(/^(\s*)def\s+[a-zA-Z_]\w*[!?=]?/m)
  return source unless match

  indent = match[1]
  source.sub(/^#{Regexp.escape(indent)}def\s+/m, "#{indent}EMBEDDED_INSTANCE_METHODS = #{names.inspect}.freeze\n#{indent}def ")
end

def transform_source(path, source)
  if %w[material_icon_lookup.rb cupertino_icon_lookup.rb].include?(path.basename.to_s)
    source = transform_icon_lookup_source(path, source)
  end

  if %w[material_icons.rb cupertino_icons.rb].include?(path.basename.to_s)
    source = transform_icon_constants_source(source)
  end

  if %w[material_control_methods.rb cupertino_control_methods.rb shared_control_forwarders.rb].include?(path.basename.to_s)
    source = transform_instance_method_constant_source(source)
  end

  if path.basename.to_s == "material_icon_lookup.rb"
    source = source.gsub('underscored = raw.gsub(/\s+|-/, "_").downcase', 'underscored = RufletEmbeddedRuntime.underscore_words(raw)')
    source = source.gsub('stripped = underscored.sub(/\Aicons\./, "")', 'stripped = RufletEmbeddedRuntime.remove_prefix(underscored, "icons.")')
    source = source.gsub('return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)', 'return text.to_i(16) if RufletEmbeddedRuntime.hex_integer_string?(text)')
    source = source.gsub('return text.to_i if text.match?(/\A\d+\z/)', 'return text.to_i if RufletEmbeddedRuntime.decimal_integer_string?(text)')
  end

  if path.basename.to_s == "cupertino_icon_lookup.rb"
    source = source.gsub('underscored = raw.gsub(/\s+|-/, "_").downcase', 'underscored = RufletEmbeddedRuntime.underscore_words(raw)')
    source = source.gsub('stripped = underscored.sub(/\Acupertinoicons\./i, "")', 'stripped = RufletEmbeddedRuntime.remove_prefix_ci(underscored, "cupertinoicons.")')
    source = source.gsub('return text.to_i(16) if text.match?(/\A0x[0-9a-fA-F]+\z/)', 'return text.to_i(16) if RufletEmbeddedRuntime.hex_integer_string?(text)')
    source = source.gsub('return text.to_i if text.match?(/\A\d+\z/)', 'return text.to_i if RufletEmbeddedRuntime.decimal_integer_string?(text)')
  end

  if path.basename.to_s == "page.rb"
    source = source.gsub(
      "Ruflet::UI::MaterialControlMethods.instance_methods(false)",
      "Ruflet::UI::MaterialControlMethods::EMBEDDED_INSTANCE_METHODS"
    )
    source = source.gsub(
      "Ruflet::UI::CupertinoControlMethods.instance_methods(false)",
      "Ruflet::UI::CupertinoControlMethods::EMBEDDED_INSTANCE_METHODS"
    )
  end

  if path.basename.to_s == "ruflet_ui.rb"
    source = source.gsub(
      "Ruflet::UI::SharedControlForwarders.instance_methods(false)",
      "Ruflet::UI::SharedControlForwarders::EMBEDDED_INSTANCE_METHODS"
    )
  end

  source = source.gsub(/^(\s*)module_function\s*$/, "\\1extend self")

  if path.basename.to_s == "control_registry.rb"
    source = source.gsub(
      /SCHEMA_EVENT_PROPS =\n.*?\.freeze\n/m,
      "SCHEMA_EVENT_PROPS = {}.freeze\n"
    )
  end

  if %w[page.rb ruflet_core.rb server.rb web_socket_connection.rb].include?(path.basename.to_s)
    source = source.gsub(/\bMutex\b/, "::Mutex")
    source = source.gsub(/\bThread\b/, "::Thread")
    source = source.gsub(/\bInterrupt\b/, "::Interrupt")
  end

  return source if path.basename.to_s == "server.rb"

  lines = source.lines
  transformed = []

  lines.each do |line|
    match = line.match(/^(\s*)def initialize\((.*)\)\s*$/)
    unless match
      transformed << line
      next
    end

    indent = match[1]
    params = match[2]
    if params.include?("&")
      transformed << line
      next
    end
    param_parts = params.split(",").map(&:strip).reject(&:empty?)
    keyword_only = param_parts.all? do |part|
      part.match?(/\A[a-zA-Z_]\w*:\s*(.+)?\z/) ||
        part.match?(/\A\*\*[a-zA-Z_]\w*\z/)
    end
    unless keyword_only
      transformed << line
      next
    end
    names = params.scan(/([a-zA-Z_]\w*):/).flatten.uniq
    if names.empty?
      transformed << line
      next
    end
    keyword_rest = param_parts.find { |part| part.match?(/\A\*\*[a-zA-Z_]\w*\z/) }
    keyword_rest_name = keyword_rest&.sub("**", "")

    transformed << "#{indent}def initialize(**__args__)\n"
    names.each do |name|
      transformed << "#{indent}  #{name} = __args__[:#{name}]\n"
    end
    if keyword_rest_name
      transformed << "#{indent}  #{keyword_rest_name} = __args__.dup\n"
      names.each do |name|
        transformed << "#{indent}  #{keyword_rest_name}.delete(:#{name})\n"
      end
    end
  end

  transformed_source = transformed.join

  if path.basename.to_s == "control.rb"
    transformed_source = transformed_source.gsub(
      /def initialize\(\*\*__args__\)\n(\s*)type = __args__\[:type\]\n\1id = __args__\[:id\]\n/,
      "def initialize(**__args__)\n\\1type = __args__[:type]\n\\1id = __args__[:id]\n\\1props = __args__.dup\n\\1props.delete(:type)\n\\1props.delete(:id)\n"
    )
    transformed_source = transformed_source.gsub(
      'format("%08x", rand(0..0xffff_ffff))',
      'RufletEmbeddedRuntime.random_hex(8)'
    )
    transformed_source = transformed_source.gsub(
      "if defined?(SecureRandom) && SecureRandom.respond_to?(:hex)",
      "if Object.const_defined?(:SecureRandom) && ::SecureRandom.respond_to?(:hex)"
    )
    transformed_source = transformed_source.gsub("SecureRandom.hex(4)", "::SecureRandom.hex(4)")
  end

  transformed_source
end

def process_file(path, ordered_paths, seen)
  return if path.nil?

  path = path.expand_path
  return if seen[path]
  raise "Missing bundled file: #{path}" unless path.file?

  seen[path] = true
  content = path.read
  stripped = strip_source_lines(path, content, ordered_paths, seen)
  ordered_paths << [path, stripped]
end

ordered_paths = []
seen = {}

BOOTSTRAP_FILES.each do |path|
  process_file(path, ordered_paths, seen)
end
process_file(BUNDLED_FEATURES.fetch("ruflet"), ordered_paths, seen)
process_file(BUNDLED_FEATURES.fetch("ruflet_server"), ordered_paths, seen)

runtime = String.new
runtime << legacy_preamble
runtime << EXTRA_SHIMS
runtime << "\n"

ordered_paths.each do |path, source|
  next if source.strip.empty?

  runtime << "\n# -- #{path.relative_path_from(ROOT)}\n\n"
  runtime << source
end

runtime << POSTAMBLE
runtime = runtime.gsub(
  "if defined?(SecureRandom) && SecureRandom.respond_to?(:hex)\n          SecureRandom.hex(4)",
  "if Object.const_defined?(:SecureRandom) && ::SecureRandom.respond_to?(:hex)\n          ::SecureRandom.hex(4)"
)
runtime = runtime.gsub('format("%08x", rand(0..0xffff_ffff))', 'RufletEmbeddedRuntime.random_hex(8)')

GENERATED_RB.write(runtime)

header = "#pragma once\n\nstatic const char* kEmbeddedRufletRuntime = R\"RUFLET_RUNTIME(\n#{runtime}\n)RUFLET_RUNTIME\";\n"
GENERATED_H.write(header)

puts "Wrote #{GENERATED_RB.relative_path_from(ROOT)}"
puts "Wrote #{GENERATED_H.relative_path_from(ROOT)}"
