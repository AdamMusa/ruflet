# -- Embedded stdlib supplement (pure Ruby)
#
# Loaded by tools/build_embedded_runtime.rb after the vendored mruby gems and
# the legacy compatibility shims. Fills standard-library gaps that the gems do
# not cover. Everything is guarded so a future gem upgrade automatically wins.
# Must stay valid mruby syntax (no autoload, no refinements). Avoid regexps
# here: this file is part of the runtime bootstrap itself.

ARGV = [] unless Object.const_defined?(:ARGV)

unless Object.const_defined?(:SystemExit)
  class SystemExit < Exception
    attr_reader :status

    def initialize(status = 0, message = "exit")
      @status = status
      super(message)
    end

    def success?
      @status == 0
    end
  end
end

module Kernel
  unless method_defined?(:exit)
    def exit(status = true)
      code =
        if status == true
          0
        elsif status == false
          1
        else
          status.to_i
        end
      raise SystemExit.new(code)
    end

    private :exit
  end

  unless method_defined?(:abort)
    def abort(message = nil)
      warn(message) if message
      raise SystemExit.new(1, message || "abort")
    end

    private :abort
  end

  unless method_defined?(:pp)
    def pp(*objects)
      objects.each { |object| puts object.inspect }
      objects.length == 1 ? objects[0] : objects
    end

    private :pp
  end
end

class Object
  unless method_defined?(:display)
    def display(port = $stdout)
      if port.respond_to?(:write)
        port.write(to_s)
      else
        print(to_s)
      end
      nil
    end
  end
end

module Enumerable
  unless method_defined?(:slice_when)
    def slice_when(&block)
      chunk_while { |before, after| !block.call(before, after) }
    end
  end
end

class Integer
  unless method_defined?(:[])
    def [](bit)
      (self >> bit) & 1
    end
  end

  unless method_defined?(:ord)
    def ord
      self
    end
  end

  unless method_defined?(:pred)
    def pred
      self - 1
    end
  end

  unless method_defined?(:gcdlcm)
    def gcdlcm(other)
      [gcd(other), lcm(other)]
    end
  end

  unless method_defined?(:coerce)
    def coerce(other)
      other.is_a?(Integer) ? [other, self] : [other.to_f, to_f]
    end
  end
end

class Float
  unless method_defined?(:coerce)
    def coerce(other)
      [other.to_f, self]
    end
  end
end

class Numeric
  unless method_defined?(:step)
    def step(limit = nil, by = 1)
      raise ArgumentError, "step can't be 0" if by == 0

      unless block_given?
        raise ArgumentError, "step without a block requires a limit" if limit.nil?

        values = []
        step(limit, by) { |value| values << value }
        return values
      end

      value = self
      if by > 0
        while limit.nil? || value <= limit
          yield value
          value += by
        end
      else
        while limit.nil? || value >= limit
          yield value
          value += by
        end
      end
      self
    end
  end

  unless method_defined?(:to_int)
    def to_int
      to_i
    end
  end
end

class Range
  unless method_defined?(:step)
    def step(by = 1)
      raise ArgumentError, "step can't be 0" if by == 0

      unless block_given?
        values = []
        step(by) { |value| values << value }
        return values
      end

      value = first
      if exclude_end?
        while value < last
          yield value
          value += by
        end
      else
        while value <= last
          yield value
          value += by
        end
      end
      self
    end
  end

  unless method_defined?(:%)
    def %(by, &block)
      step(by, &block)
    end
  end
end

class Symbol
  unless method_defined?(:[])
    def [](*args)
      to_s[*args]
    end
  end

  unless method_defined?(:slice)
    def slice(*args)
      to_s[*args]
    end
  end

  unless method_defined?(:start_with?)
    def start_with?(*prefixes)
      to_s.start_with?(*prefixes)
    end
  end

  unless method_defined?(:end_with?)
    def end_with?(*suffixes)
      to_s.end_with?(*suffixes)
    end
  end

  unless method_defined?(:succ)
    def succ
      to_s.succ.to_sym
    end
  end

  unless method_defined?(:next)
    def next
      to_s.succ.to_sym
    end
  end

  unless method_defined?(:swapcase)
    def swapcase
      to_s.swapcase.to_sym
    end
  end
end

class Exception
  unless method_defined?(:cause)
    def cause
      nil
    end
  end

  unless method_defined?(:full_message)
    def full_message(*)
      lines = ["#{message} (#{self.class})"]
      trace = backtrace
      trace.each { |entry| lines << "\tfrom #{entry}" } if trace
      lines.join("\n")
    end
  end
end

class String
  unless method_defined?(:encode)
    # Single-encoding VM: encoding conversion is the identity.
    def encode(*)
      dup
    end
  end

  unless method_defined?(:scrub)
    def scrub(*)
      dup
    end
  end
end

class File
  unless respond_to?(:mtime)
    def self.mtime(path)
      open(path.to_s, "r") { |file| file.mtime }
    end
  end

  unless respond_to?(:atime)
    def self.atime(path)
      open(path.to_s, "r") { |file| file.atime }
    end
  end

  unless respond_to?(:ctime)
    def self.ctime(path)
      open(path.to_s, "r") { |file| file.ctime }
    end
  end

  unless respond_to?(:binread)
    def self.binread(path, length = nil, offset = 0)
      open(path.to_s, "rb") do |file|
        file.seek(offset) if offset && offset > 0
        length.nil? ? file.read : file.read(length)
      end
    end
  end

  unless respond_to?(:binwrite)
    def self.binwrite(path, content)
      open(path.to_s, "wb") { |file| file.write(content.to_s) }
    end
  end

  unless respond_to?(:split)
    def self.split(path)
      [dirname(path.to_s), basename(path.to_s)]
    end
  end

  unless respond_to?(:ftype)
    def self.ftype(path)
      text = path.to_s
      if symlink?(text)
        "link"
      elsif directory?(text)
        "directory"
      elsif file?(text)
        "file"
      else
        "unknown"
      end
    end
  end
end

module JSON
  unless respond_to?(:generate)
    class << self
      def generate(value)
        __generate_value(value)
      end

      def dump(value)
        generate(value)
      end

      def pretty_generate(value, indent = "  ")
        __pretty_value(value, indent, 0)
      end

      def __generate_value(value)
        case value
        when nil then "null"
        when true then "true"
        when false then "false"
        when Integer, Float then value.to_s
        when String then __generate_string(value)
        when Symbol then __generate_string(value.to_s)
        when Hash
          pairs = []
          value.each do |key, item|
            pairs << "#{__generate_string(__json_key(key))}:#{__generate_value(item)}"
          end
          "{#{pairs.join(",")}}"
        when Array
          "[#{value.map { |item| __generate_value(item) }.join(",")}]"
        else
          if value.respond_to?(:to_h)
            __generate_value(value.to_h)
          elsif value.respond_to?(:to_a)
            __generate_value(value.to_a)
          else
            __generate_string(value.to_s)
          end
        end
      end

      def __pretty_value(value, indent, depth)
        case value
        when Hash
          return "{}" if value.empty?

          inner = indent * (depth + 1)
          pairs = []
          value.each do |key, item|
            pairs << "#{inner}#{__generate_string(__json_key(key))}: #{__pretty_value(item, indent, depth + 1)}"
          end
          "{\n#{pairs.join(",\n")}\n#{indent * depth}}"
        when Array
          return "[]" if value.empty?

          inner = indent * (depth + 1)
          items = value.map { |item| "#{inner}#{__pretty_value(item, indent, depth + 1)}" }
          "[\n#{items.join(",\n")}\n#{indent * depth}]"
        else
          __generate_value(value)
        end
      end

      def __json_key(key)
        key.is_a?(String) ? key : key.to_s
      end

      def __generate_string(text)
        out = "\""
        text.to_s.each_byte do |byte|
          if byte == 34
            out += "\\\""
          elsif byte == 92
            out += "\\\\"
          elsif byte == 8
            out += "\\b"
          elsif byte == 12
            out += "\\f"
          elsif byte == 10
            out += "\\n"
          elsif byte == 13
            out += "\\r"
          elsif byte == 9
            out += "\\t"
          elsif byte < 32
            out += "\\u" + ("%04x" % byte)
          else
            out += [byte].pack("C")
          end
        end
        out + "\""
      end
    end
  end
end

[Hash, Array, String, Integer, Float, Symbol, TrueClass, FalseClass, NilClass].each do |klass|
  unless klass.method_defined?(:to_json)
    klass.class_eval do
      def to_json(*)
        JSON.generate(self)
      end
    end
  end
end

unless Object.const_defined?(:StringIO)
  class StringIO
    attr_reader :string
    attr_accessor :sync

    def initialize(string = "")
      @string = string.to_s
      @pos = 0
      @closed = false
      @sync = true
    end

    def self.open(string = "")
      io = new(string)
      return io unless block_given?

      begin
        yield(io)
      ensure
        io.close
      end
    end

    def pos
      @pos
    end
    alias tell pos

    def pos=(value)
      @pos = value.to_i
    end

    def seek(offset, whence = 0)
      @pos =
        case whence
        when 1 then @pos + offset.to_i
        when 2 then @string.length + offset.to_i
        else offset.to_i
        end
      0
    end

    def rewind
      @pos = 0
      0
    end

    def eof?
      @pos >= @string.length
    end
    alias eof eof?

    def read(length = nil, out = nil)
      if length.nil?
        chunk = @string[@pos..-1].to_s
        @pos = @string.length
        result = chunk
      else
        return nil if eof?

        chunk = @string[@pos, length].to_s
        @pos += chunk.length
        result = chunk
      end
      out ? out.replace(result) : result
    end

    def getc
      return nil if eof?

      char = @string[@pos, 1]
      @pos += 1
      char
    end

    def getbyte
      return nil if eof?

      byte = @string.getbyte(@pos)
      @pos += 1
      byte
    end

    def gets(separator = "\n")
      return nil if eof?

      index = @string.index(separator, @pos)
      if index.nil?
        read
      else
        line = @string[@pos, index - @pos + separator.length]
        @pos = index + separator.length
        line
      end
    end

    def each_line(separator = "\n")
      while (line = gets(separator))
        yield line
      end
      self
    end

    def readlines(separator = "\n")
      lines = []
      each_line(separator) { |line| lines << line }
      lines
    end

    def write(*chunks)
      total = 0
      chunks.each do |chunk|
        text = chunk.to_s
        if @pos >= @string.length
          @string = @string + text
        else
          @string = @string[0, @pos].to_s + text + @string[@pos + text.length..-1].to_s
        end
        @pos += text.length
        total += text.length
      end
      total
    end

    def <<(chunk)
      write(chunk)
      self
    end

    def print(*chunks)
      chunks.each { |chunk| write(chunk) }
      nil
    end

    def puts(*lines)
      if lines.empty?
        write("\n")
      else
        lines.each do |line|
          if line.is_a?(Array)
            puts(*line)
          else
            text = line.to_s
            write(text)
            write("\n") unless text.end_with?("\n")
          end
        end
      end
      nil
    end

    def printf(format, *args)
      write(sprintf(format, *args))
      nil
    end

    def truncate(length)
      @string = @string[0, length].to_s
      0
    end

    def size
      @string.length
    end
    alias length size

    def flush
      self
    end

    def close
      @closed = true
      nil
    end

    def closed?
      @closed
    end
  end
end

unless Object.const_defined?(:OpenStruct)
  class OpenStruct
    def initialize(hash = nil)
      @table = {}
      hash.each { |key, value| @table[key.to_sym] = value } if hash
    end

    def [](key)
      @table[key.to_sym]
    end

    def []=(key, value)
      @table[key.to_sym] = value
    end

    def to_h
      out = {}
      @table.each { |key, value| out[key] = value }
      out
    end

    def each_pair(&block)
      @table.each_pair(&block)
      self
    end

    def dig(key, *rest)
      value = @table[key.to_sym]
      rest.empty? ? value : value&.dig(*rest)
    end

    def delete_field(key)
      @table.delete(key.to_sym)
    end

    def respond_to_missing?(name, _include_private = false)
      text = name.to_s
      text.end_with?("=") || @table.key?(name.to_sym) || super
    end

    def method_missing(name, *args)
      text = name.to_s
      if text.end_with?("=")
        @table[text[0, text.length - 1].to_sym] = args[0]
      elsif args.empty?
        @table[name]
      else
        super
      end
    end

    def ==(other)
      other.is_a?(OpenStruct) && to_h == other.to_h
    end

    def inspect
      pairs = @table.map { |key, value| " #{key}=#{value.inspect}" }
      "#<OpenStruct#{pairs.join(",")}>"
    end
    alias to_s inspect
  end
end

unless Object.const_defined?(:Forwardable)
  module Forwardable
    def def_delegator(accessor, method, alias_name = method)
      accessor = accessor.to_s
      define_method(alias_name) do |*args, &block|
        target =
          if accessor.start_with?("@")
            instance_variable_get(accessor)
          else
            __send__(accessor)
          end
        target.__send__(method, *args, &block)
      end
    end

    def def_delegators(accessor, *methods)
      methods.each { |method| def_delegator(accessor, method) }
    end

    alias def_instance_delegator def_delegator
    alias def_instance_delegators def_delegators
  end
end

unless Object.const_defined?(:Base64)
  module Base64
    extend self

    def encode64(data)
      [data].pack("m")
    end

    def decode64(data)
      data.unpack1("m")
    end

    def strict_encode64(data)
      [data].pack("m0")
    end

    def strict_decode64(data)
      data.unpack1("m0")
    end

    def urlsafe_encode64(data, padding: true)
      text = strict_encode64(data).tr("+/", "-_")
      padding ? text : text.delete("=")
    end

    def urlsafe_decode64(data)
      text = data.tr("-_", "+/")
      text += "=" * ((4 - (text.length % 4)) % 4)
      strict_decode64(text)
    end
  end
end

if Object.const_defined?(:Time)
  class Time
    unless method_defined?(:strftime)
      STRFTIME_DAY_NAMES = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
      STRFTIME_MONTH_NAMES = %w[
        January February March April May June July
        August September October November December
      ].freeze

      def strftime(format)
        out = ""
        index = 0
        text = format.to_s
        while index < text.length
          char = text[index, 1]
          if char != "%" || index == text.length - 1
            out += char
            index += 1
            next
          end

          directive = text[index + 1, 1]
          out += __strftime_directive(directive)
          index += 2
        end
        out
      end

      def iso8601(fraction_digits = 0)
        base = strftime("%Y-%m-%dT%H:%M:%S")
        if fraction_digits > 0
          fraction = (usec / 1_000_000.0).to_s[2, fraction_digits].to_s
          fraction += "0" * (fraction_digits - fraction.length)
          base += ".#{fraction}"
        end
        base + __strftime_zone(":")
      end

      private

      def __strftime_directive(directive)
        case directive
        when "Y" then year.to_s
        when "y" then "%02d" % (year % 100)
        when "m" then "%02d" % mon
        when "d" then "%02d" % mday
        when "e" then "%2d" % mday
        when "H" then "%02d" % hour
        when "I" then "%02d" % (((hour + 11) % 12) + 1)
        when "M" then "%02d" % min
        when "S" then "%02d" % sec
        when "L" then "%03d" % (usec / 1000)
        when "N" then "%09d" % (usec * 1000)
        when "p" then hour < 12 ? "AM" : "PM"
        when "P" then hour < 12 ? "am" : "pm"
        when "a" then STRFTIME_DAY_NAMES[wday][0, 3]
        when "A" then STRFTIME_DAY_NAMES[wday]
        when "b", "h" then STRFTIME_MONTH_NAMES[mon - 1][0, 3]
        when "B" then STRFTIME_MONTH_NAMES[mon - 1]
        when "j" then "%03d" % yday
        when "u" then (wday == 0 ? 7 : wday).to_s
        when "w" then wday.to_s
        when "s" then to_i.to_s
        when "z" then __strftime_zone("")
        when "Z" then utc? ? "UTC" : zone.to_s
        when "F" then strftime("%Y-%m-%d")
        when "T", "X" then strftime("%H:%M:%S")
        when "R" then strftime("%H:%M")
        when "D", "x" then strftime("%m/%d/%y")
        when "c" then strftime("%a %b %e %H:%M:%S %Y")
        when "n" then "\n"
        when "t" then "\t"
        when "%" then "%"
        else "%" + directive.to_s
        end
      end

      def __strftime_zone(separator)
        offset = utc_offset
        sign = offset < 0 ? "-" : "+"
        offset = -offset if offset < 0
        hours = offset / 3600
        minutes = (offset % 3600) / 60
        "#{sign}#{"%02d" % hours}#{separator}#{"%02d" % minutes}"
      end
    end
  end
end
