# -- Embedded Regexp engine (pure Ruby)
#
# mruby has no core regexp engine, but its compiler accepts regexp literal
# syntax and emits `Regexp.compile(pattern, flags)` calls (see mruby/re.h and
# codegen_regx in mruby-compiler). Defining Regexp here makes regex literals,
# String#match/scan/gsub/split-with-regexp, and `case ... when /re/` work
# out of the box.
#
# Supported syntax: literals, `.`, character classes (ranges, negation,
# shorthands), `\d \D \w \W \s \S \h \H`, anchors `^ $ \A \z \Z \b \B`,
# greedy/lazy quantifiers `* + ? {n} {n,} {n,m}`, groups (capturing,
# `(?:...)`, named `(?<name>...)`), alternation, backreferences `\1`..`\9`,
# lookahead `(?=...)` / `(?!...)`, and the `i m x` options. Byte-oriented:
# case folding and shorthands are ASCII. Lookbehind and unicode property
# classes are not supported and raise RegexpError.

unless Object.const_defined?(:RegexpError)
  class RegexpError < StandardError
  end
end

unless Object.const_defined?(:Regexp)
  class Regexp
    IGNORECASE = 1
    EXTENDED = 2
    MULTILINE = 4

    attr_reader :source, :options

    class << self
      def compile(source, options = nil, _encoding = nil)
        new(source, options)
      end

      def escape(text)
        out = ""
        text.to_s.each_byte do |byte|
          char = [byte].pack("C")
          if SPECIALS_FOR_ESCAPE[char]
            out += "\\" + char
          elsif byte == 10
            out += "\\n"
          elsif byte == 13
            out += "\\r"
          elsif byte == 9
            out += "\\t"
          elsif byte == 12
            out += "\\f"
          elsif byte == 11
            out += "\\v"
          else
            out += char
          end
        end
        out
      end
      alias quote escape

      def union(*patterns)
        patterns = patterns[0] if patterns.length == 1 && patterns[0].is_a?(Array)
        return new("(?!)") if patterns.empty?

        sources = patterns.map do |pattern|
          pattern.is_a?(Regexp) ? pattern.source : escape(pattern.to_s)
        end
        new(sources.join("|"))
      end

      def last_match(index = nil)
        match = $~
        return match if index.nil?
        return nil if match.nil?

        match[index]
      end
    end

    SPECIALS_FOR_ESCAPE = {
      "." => true, "*" => true, "+" => true, "?" => true, "^" => true,
      "$" => true, "(" => true, ")" => true, "[" => true, "]" => true,
      "{" => true, "}" => true, "|" => true, "\\" => true, "-" => true,
      "/" => true, " " => true, "#" => true
    }.freeze

    def initialize(source, options = nil)
      if source.is_a?(Regexp)
        @source = source.source
        @options = options.nil? ? source.options : normalize_options(options)
      else
        @source = source.to_s
        @options = normalize_options(options)
      end

      parser = Parser.new(@source, @options)
      @root = parser.parse
      @group_count = parser.group_count
      @group_names = parser.group_names
    end

    def casefold?
      (@options & IGNORECASE) != 0
    end

    def names
      @group_names.keys
    end

    def named_captures
      out = {}
      @group_names.each { |name, index| out[name] = [index] }
      out
    end

    def match(text, pos = 0)
      return ($~ = nil) if text.nil?

      text = text.to_s
      matcher = Matcher.new(@root, text, @options, @group_count)
      index = pos
      index += text.length if index < 0
      return ($~ = nil) if index < 0 || index > text.length

      while index <= text.length
        caps = matcher.match_at(index)
        if caps
          match_data = MatchData.new(self, text, caps, @group_names)
          $~ = match_data
          return match_data
        end
        index += 1
      end
      $~ = nil
    end

    def match?(text, pos = 0)
      return false if text.nil?

      text = text.to_s
      matcher = Matcher.new(@root, text, @options, @group_count)
      index = pos
      index += text.length if index < 0
      return false if index < 0 || index > text.length

      while index <= text.length
        return true if matcher.match_at(index)

        index += 1
      end
      false
    end

    def =~(text)
      match_data = match(text)
      match_data ? match_data.begin(0) : nil
    end

    def ===(text)
      value =
        if text.is_a?(String) || text.is_a?(Symbol)
          text.to_s
        elsif text.respond_to?(:to_str)
          text.to_str
        else
          return false
        end
      !match(value).nil?
    end

    def ==(other)
      other.is_a?(Regexp) && other.source == @source && other.options == @options
    end
    alias eql? ==

    def hash
      (@source.hash * 31) + @options
    end

    def to_s
      flags_on = ""
      flags_off = ""
      flags_on += "m" if (@options & MULTILINE) != 0
      flags_on += "i" if (@options & IGNORECASE) != 0
      flags_on += "x" if (@options & EXTENDED) != 0
      flags_off += "m" if (@options & MULTILINE) == 0
      flags_off += "i" if (@options & IGNORECASE) == 0
      flags_off += "x" if (@options & EXTENDED) == 0
      body = flags_off.empty? ? flags_on : "#{flags_on}-#{flags_off}"
      "(?#{body}:#{@source})"
    end

    def inspect
      flags = ""
      flags += "m" if (@options & MULTILINE) != 0
      flags += "i" if (@options & IGNORECASE) != 0
      flags += "x" if (@options & EXTENDED) != 0
      "/#{@source}/#{flags}"
    end

    private

    def normalize_options(options)
      case options
      when nil, false then 0
      when true then IGNORECASE
      when Integer then options
      when String, Symbol
        value = 0
        options.to_s.each_char do |char|
          case char
          when "i" then value |= IGNORECASE
          when "m" then value |= MULTILINE
          when "x" then value |= EXTENDED
          when "o", "u", "n", "e", "s" then nil # encoding/once flags: ignored
          end
        end
        value
      else
        0
      end
    end

    # ------------------------------------------------------------------
    # Pattern parser: builds an AST of plain arrays.
    #   [:char, byte]                     [:any]
    #   [:class, negated, ranges, shorthands(neg inside)]
    #   [:seq, children]                  [:alt, branches]
    #   [:group, index_or_nil, child]     [:repeat, child, min, max, greedy]
    #   [:anchor, kind]                   [:backref, index]
    #   [:look, positive, child]
    # ------------------------------------------------------------------
    class Parser
      attr_reader :group_count, :group_names

      def initialize(source, options)
        @src = source
        @len = source.bytesize
        @pos = 0
        @options = options
        @group_count = 0
        @group_names = {}
      end

      def parse
        node = parse_alternation
        error("unmatched )") unless @pos >= @len
        node
      end

      private

      def extended?
        (@options & EXTENDED) != 0
      end

      def error(message)
        raise RegexpError, "#{message} in regexp: /#{@src}/"
      end

      def peek
        @src.getbyte(@pos)
      end

      def advance
        byte = @src.getbyte(@pos)
        @pos += 1
        byte
      end

      def parse_alternation
        branches = [parse_sequence]
        while peek == 124 # |
          advance
          branches << parse_sequence
        end
        branches.length == 1 ? branches[0] : [:alt, branches]
      end

      def parse_sequence
        items = []
        loop do
          byte = peek
          break if byte.nil? || byte == 124 || byte == 41 # | )

          if extended?
            if byte == 32 || byte == 9 || byte == 10 || byte == 13 || byte == 12
              advance
              next
            end
            if byte == 35 # '#' comment to end of line
              advance while peek && peek != 10
              next
            end
          end

          atom = parse_atom
          next if atom.nil?

          atom = parse_quantifier(atom)
          items << atom
        end
        items.length == 1 ? items[0] : [:seq, items]
      end

      def parse_quantifier(atom)
        byte = peek
        min = nil
        max = nil

        case byte
        when 42 then advance; min = 0; max = nil   # *
        when 43 then advance; min = 1; max = nil   # +
        when 63 then advance; min = 0; max = 1     # ?
        when 123 # {
          saved = @pos
          advance
          digits1 = read_digits
          if peek == 125 && digits1 # {n}
            advance
            min = digits1
            max = digits1
          elsif peek == 44 # ,
            advance
            digits2 = read_digits
            if peek == 125
              advance
              min = digits1 || 0
              max = digits2
            else
              @pos = saved
              return atom
            end
          else
            @pos = saved
            return atom
          end
        else
          return atom
        end

        greedy = true
        if peek == 63 # lazy
          advance
          greedy = false
        elsif peek == 43 # possessive: treat as greedy
          advance
        end

        [:repeat, atom, min, max, greedy]
      end

      def read_digits
        start = @pos
        advance while peek && peek >= 48 && peek <= 57
        return nil if @pos == start

        @src.byteslice(start, @pos - start).to_i
      end

      def parse_atom
        byte = advance
        case byte
        when 46 then [:any]                       # .
        when 94 then [:anchor, :bol]              # ^
        when 36 then [:anchor, :eol]              # $
        when 40 then parse_group                  # (
        when 91 then parse_class                  # [
        when 92 then parse_escape(false)          # \
        when 41 then error("unmatched )")
        when 42, 43 then error("target of repeat operator is not specified")
        else
          [:char, fold(byte)]
        end
      end

      def parse_group
        if peek == 63 # ?
          advance
          byte = advance
          case byte
          when 58 # (?:
            node = parse_alternation
            expect_close
            node
          when 61 # (?=
            node = parse_alternation
            expect_close
            [:look, true, node]
          when 33 # (?!
            node = parse_alternation
            expect_close
            [:look, false, node]
          when 60 # (?<
            if peek == 61 || peek == 33
              error("lookbehind is not supported by the embedded Regexp engine")
            end
            name = read_group_name(62) # >
            capture_group(name)
          when 39 # (?'
            name = read_group_name(39)
            capture_group(name)
          when 35 # (?# comment)
            advance while peek && peek != 41
            expect_close
            nil
          else
            # inline options like (?i) / (?i:...)
            parse_inline_options(byte)
          end
        else
          capture_group(nil)
        end
      end

      def parse_inline_options(first_byte)
        on = 0
        off = 0
        negate = false
        byte = first_byte
        loop do
          case byte
          when 105 then negate ? off |= IGNORECASE : on |= IGNORECASE # i
          when 109 then negate ? off |= MULTILINE : on |= MULTILINE   # m
          when 120 then negate ? off |= EXTENDED : on |= EXTENDED     # x
          when 45 then negate = true                                  # -
          when 58, 41 then break                                      # : )
          else error("unsupported group option")
          end
          byte = advance
        end

        previous = @options
        @options = (@options | on) & ~off
        if byte == 58 # scoped (?i:...)
          node = parse_alternation
          expect_close
          @options = previous
          node
        else
          # (?i) applies to the rest of the current group; keep it active.
          nil
        end
      end

      def read_group_name(terminator)
        name = ""
        while peek && peek != terminator
          name += [advance].pack("C")
        end
        error("invalid group name") if name.empty? || peek.nil?
        advance
        name
      end

      def capture_group(name)
        @group_count += 1
        index = @group_count
        @group_names[name] = index if name
        node = parse_alternation
        expect_close
        [:group, index, node]
      end

      def expect_close
        error("unmatched (") unless peek == 41
        advance
      end

      def parse_class
        negated = false
        if peek == 94 # ^
          advance
          negated = true
        end

        ranges = []
        shorthands = []
        first = true
        loop do
          byte = peek
          error("premature end of char-class") if byte.nil?
          if byte == 93 && !first # ]
            advance
            break
          end
          first = false
          advance

          if byte == 92 # escape inside class
            item = parse_escape(true)
            case item[0]
            when :char
              add_class_member(ranges, item[1])
            when :short
              shorthands << item[1]
            else
              error("unsupported escape in char-class")
            end
            next
          end

          lo = byte
          if peek == 45 && @src.getbyte(@pos + 1) && @src.getbyte(@pos + 1) != 93
            advance # -
            hi_byte = advance
            if hi_byte == 92
              hi_item = parse_escape(true)
              error("invalid range in char-class") unless hi_item[0] == :char
              hi_byte = hi_item[1]
            end
            error("empty range in char class") if hi_byte < lo
            ranges << lo << hi_byte
          else
            add_class_member(ranges, lo)
          end
        end

        [:class, negated, ranges, shorthands]
      end

      def add_class_member(ranges, byte)
        ranges << byte << byte
        if (@options & IGNORECASE) != 0
          if byte >= 65 && byte <= 90
            ranges << byte + 32 << byte + 32
          elsif byte >= 97 && byte <= 122
            ranges << byte - 32 << byte - 32
          end
        end
      end

      def parse_escape(in_class)
        byte = advance
        error("too short escape sequence") if byte.nil?

        case byte
        when 100 then in_class ? [:short, :d] : [:class, false, [], [:d]]   # \d
        when 68 then in_class ? [:short, :D] : [:class, false, [], [:D]]    # \D
        when 119 then in_class ? [:short, :w] : [:class, false, [], [:w]]   # \w
        when 87 then in_class ? [:short, :W] : [:class, false, [], [:W]]    # \W
        when 115 then in_class ? [:short, :s] : [:class, false, [], [:s]]   # \s
        when 83 then in_class ? [:short, :S] : [:class, false, [], [:S]]    # \S
        when 104 then in_class ? [:short, :h] : [:class, false, [], [:h]]   # \h
        when 72 then in_class ? [:short, :H] : [:class, false, [], [:H]]    # \H
        when 65 then in_class ? [:char, 65] : [:anchor, :bos]               # \A
        when 122 then in_class ? [:char, 122] : [:anchor, :eos]             # \z
        when 90 then in_class ? [:char, 90] : [:anchor, :eos_nl]            # \Z
        when 98 then in_class ? [:char, 8] : [:anchor, :wb]                 # \b
        when 66 then in_class ? [:char, 66] : [:anchor, :nwb]               # \B
        when 71 then error("\\G is not supported")
        when 110 then [:char, 10]   # \n
        when 116 then [:char, 9]    # \t
        when 114 then [:char, 13]   # \r
        when 102 then [:char, 12]   # \f
        when 118 then [:char, 11]   # \v
        when 97 then [:char, 7]     # \a
        when 101 then [:char, 27]   # \e
        when 48 then [:char, 0]     # \0
        when 120 # \xHH
          value = 0
          count = 0
          while count < 2 && hex_digit?(peek)
            value = (value * 16) + hex_value(advance)
            count += 1
          end
          error("invalid hex escape") if count.zero?
          [:char, value]
        when 49, 50, 51, 52, 53, 54, 55, 56, 57 # \1..\9
          if in_class
            [:char, byte]
          else
            [:backref, byte - 48]
          end
        when 107 # \k<name>
          if !in_class && (peek == 60 || peek == 39)
            terminator = advance == 60 ? 62 : 39
            name = ""
            while peek && peek != terminator
              name += [advance].pack("C")
            end
            advance
            index = @group_names[name]
            error("undefined group name #{name}") unless index
            [:backref, index]
          else
            [:char, 107]
          end
        when 112, 80 # \p{...} unicode property
          error("unicode property classes are not supported by the embedded Regexp engine")
        else
          [:char, fold(byte)]
        end
      end

      def hex_digit?(byte)
        return false if byte.nil?

        (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102) || (byte >= 65 && byte <= 70)
      end

      def hex_value(byte)
        return byte - 48 if byte <= 57
        return byte - 87 if byte >= 97

        byte - 55
      end

      def fold(byte)
        if (@options & IGNORECASE) != 0 && byte >= 65 && byte <= 90
          byte + 32
        else
          byte
        end
      end
    end

    # ------------------------------------------------------------------
    # Backtracking matcher (continuation passing).
    # ------------------------------------------------------------------
    class Matcher
      def initialize(root, text, options, group_count)
        @root = root
        @text = text
        @len = text.bytesize
        @ignorecase = (options & IGNORECASE) != 0
        @multiline = (options & MULTILINE) != 0
        @group_count = group_count
      end

      # Returns the captures array [[start,stop], ...] or nil.
      def match_at(start)
        @caps = Array.new(@group_count + 1)
        finish = walk(@root, start, IDENTITY)
        return nil unless finish

        @caps[0] = [start, finish]
        @caps
      end

      IDENTITY = lambda { |pos| pos }

      private

      def byte_at(pos)
        byte = @text.getbyte(pos)
        return nil if byte.nil?

        @ignorecase && byte >= 65 && byte <= 90 ? byte + 32 : byte
      end

      def raw_byte(pos)
        @text.getbyte(pos)
      end

      def word_byte?(byte)
        return false if byte.nil?

        (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) ||
          (byte >= 97 && byte <= 122) || byte == 95
      end

      def short_member?(kind, byte)
        case kind
        when :d then byte >= 48 && byte <= 57
        when :D then !(byte >= 48 && byte <= 57)
        when :w then word_byte?(byte)
        when :W then !word_byte?(byte)
        when :s then byte == 32 || (byte >= 9 && byte <= 13)
        when :S then !(byte == 32 || (byte >= 9 && byte <= 13))
        when :h then (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102) || (byte >= 65 && byte <= 70)
        when :H then !((byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102) || (byte >= 65 && byte <= 70))
        else false
        end
      end

      def class_member?(node, pos)
        byte = raw_byte(pos)
        return false if byte.nil?

        negated = node[1]
        ranges = node[2]
        shorthands = node[3]

        hit = false
        index = 0
        while index < ranges.length
          if byte >= ranges[index] && byte <= ranges[index + 1]
            hit = true
            break
          end
          index += 2
        end
        unless hit
          shorthands.each do |kind|
            if short_member?(kind, byte)
              hit = true
              break
            end
          end
        end
        # case-insensitive: retry with swapped case against plain ranges
        if !hit && @ignorecase
          swapped =
            if byte >= 65 && byte <= 90 then byte + 32
            elsif byte >= 97 && byte <= 122 then byte - 32
            end
          if swapped
            index = 0
            while index < ranges.length
              if swapped >= ranges[index] && swapped <= ranges[index + 1]
                hit = true
                break
              end
              index += 2
            end
          end
        end

        negated ? !hit : hit
      end

      # True when the node consumes exactly one byte and has no captures —
      # eligible for the iterative repeat fast path.
      def simple_node?(node)
        node[0] == :char || node[0] == :any || node[0] == :class
      end

      def single_byte_match?(node, pos)
        case node[0]
        when :char
          byte_at(pos) == node[1]
        when :any
          byte = raw_byte(pos)
          !byte.nil? && (@multiline || byte != 10)
        when :class
          pos < @len && class_member?(node, pos)
        else
          false
        end
      end

      def walk(node, pos, k)
        case node[0]
        when :char
          byte_at(pos) == node[1] ? k.call(pos + 1) : nil
        when :any
          byte = raw_byte(pos)
          !byte.nil? && (@multiline || byte != 10) ? k.call(pos + 1) : nil
        when :class
          pos < @len && class_member?(node, pos) ? k.call(pos + 1) : nil
        when :seq
          walk_seq(node[1], 0, pos, k)
        when :alt
          node[1].each do |branch|
            result = walk(branch, pos, k)
            return result if result
          end
          nil
        when :group
          index = node[1]
          saved = @caps[index]
          start = pos
          result = walk(node[2], pos, lambda { |stop|
            @caps[index] = [start, stop]
            k.call(stop)
          })
          @caps[index] = saved unless result
          result
        when :repeat
          walk_repeat(node, pos, k)
        when :anchor
          anchor_ok?(node[1], pos) ? k.call(pos) : nil
        when :backref
          cap = @caps[node[1]]
          return nil if cap.nil?

          length = cap[1] - cap[0]
          return nil if pos + length > @len

          captured = @text.byteslice(cap[0], length).to_s
          actual = @text.byteslice(pos, length).to_s
          if @ignorecase
            captured = captured.downcase
            actual = actual.downcase
          end
          captured == actual ? k.call(pos + length) : nil
        when :look
          positive = node[1]
          found = walk(node[2], pos, IDENTITY)
          (positive ? found : !found) ? k.call(pos) : nil
        else
          nil
        end
      end

      def walk_seq(items, index, pos, k)
        return k.call(pos) if index >= items.length
        return walk(items[index], pos, k) if index == items.length - 1

        walk(items[index], pos, lambda { |next_pos| walk_seq(items, index + 1, next_pos, k) })
      end

      def walk_repeat(node, pos, k)
        inner = node[1]
        min = node[2]
        max = node[3]
        greedy = node[4]

        # Fast path: single-byte atoms backtrack with a loop, not recursion.
        if simple_node?(inner)
          count = 0
          probe = pos
          limit = max
          while (limit.nil? || count < limit) && single_byte_match?(inner, probe)
            probe += 1
            count += 1
          end
          return nil if count < min

          if greedy
            while count >= min
              result = k.call(pos + count)
              return result if result

              count -= 1
            end
            nil
          else
            attempt = min
            while attempt <= count
              result = k.call(pos + attempt)
              return result if result

              attempt += 1
            end
            nil
          end
        else
          repeat_general(inner, min, max, greedy, 0, pos, k)
        end
      end

      def repeat_general(inner, min, max, greedy, count, pos, k)
        if greedy
          if max.nil? || count < max
            result = walk(inner, pos, lambda { |next_pos|
              # zero-width progress guard
              if next_pos == pos && count >= min
                nil
              else
                repeat_general(inner, min, max, greedy, count + 1, next_pos, k)
              end
            })
            return result if result
          end
          count >= min ? k.call(pos) : nil
        else
          if count >= min
            result = k.call(pos)
            return result if result
          end
          if max.nil? || count < max
            walk(inner, pos, lambda { |next_pos|
              next_pos == pos ? nil : repeat_general(inner, min, max, greedy, count + 1, next_pos, k)
            })
          end
        end
      end

      def anchor_ok?(kind, pos)
        case kind
        when :bos then pos.zero?
        when :eos then pos == @len
        when :eos_nl then pos == @len || (pos == @len - 1 && raw_byte(pos) == 10)
        when :bol then pos.zero? || raw_byte(pos - 1) == 10
        when :eol then pos == @len || raw_byte(pos) == 10
        when :wb then word_byte?(raw_byte(pos - 1)) != word_byte?(raw_byte(pos))
        when :nwb then word_byte?(raw_byte(pos - 1)) == word_byte?(raw_byte(pos))
        else false
        end
      end
    end
  end
end

unless Object.const_defined?(:MatchData)
  class MatchData
    def initialize(regexp, string, caps, names)
      @regexp = regexp
      @string = string
      @caps = caps
      @names = names
    end

    def regexp
      @regexp
    end

    def string
      @string
    end

    def size
      @caps.length
    end
    alias length size

    def names
      @names.keys
    end

    def [](key, *rest)
      unless rest.empty?
        # [start, length] slice over the capture list
        return to_a[key, rest[0]]
      end

      case key
      when Integer
        slice_for(key < 0 ? @caps.length + key : key)
      when String, Symbol
        index = @names[key.to_s]
        raise IndexError, "undefined group name reference: #{key}" unless index

        slice_for(index)
      when Range
        to_a[key]
      end
    end

    def begin(index)
      cap = cap_for(index)
      cap && cap[0]
    end

    def end(index)
      cap = cap_for(index)
      cap && cap[1]
    end

    def offset(index)
      cap = cap_for(index)
      cap ? [cap[0], cap[1]] : [nil, nil]
    end

    def to_a
      (0...@caps.length).map { |index| slice_for(index) }
    end

    def captures
      (1...@caps.length).map { |index| slice_for(index) }
    end

    def named_captures
      out = {}
      @names.each { |name, index| out[name] = slice_for(index) }
      out
    end

    def values_at(*indexes)
      indexes.map { |index| self[index] }
    end

    def pre_match
      @string.byteslice(0, @caps[0][0]).to_s
    end

    def post_match
      @string.byteslice(@caps[0][1], @string.bytesize - @caps[0][1]).to_s
    end

    def to_s
      slice_for(0)
    end

    def deconstruct
      captures
    end

    def deconstruct_keys(keys)
      out = named_captures
      symbolized = {}
      out.each { |name, value| symbolized[name.to_sym] = value }
      return symbolized if keys.nil?

      keys.each_with_object({}) do |key, acc|
        acc[key] = symbolized[key] if symbolized.key?(key)
      end
    end

    def inspect
      parts = ["#<MatchData #{slice_for(0).inspect}"]
      (1...@caps.length).each do |index|
        name = @names.key(index) || index.to_s
        parts << " #{name}:#{slice_for(index).inspect}"
      end
      parts.join + ">"
    end

    private

    def cap_for(index)
      if index.is_a?(String) || index.is_a?(Symbol)
        index = @names[index.to_s]
        return nil unless index
      end
      @caps[index]
    end

    def slice_for(index)
      cap = @caps[index]
      return nil if cap.nil?

      @string.byteslice(cap[0], cap[1] - cap[0]).to_s
    end
  end
end

# ------------------------------------------------------------------
# String integration: extend core methods to accept Regexp patterns.
# ------------------------------------------------------------------
class String
  def __regexp_coerce(pattern)
    pattern.is_a?(Regexp) ? pattern : Regexp.new(Regexp.escape(pattern.to_s))
  end
  private :__regexp_coerce

  unless method_defined?(:=~)
    def =~(pattern)
      raise TypeError, "type mismatch: String given" if pattern.is_a?(String)

      pattern =~ self if pattern.respond_to?(:=~)
    end
  end

  unless method_defined?(:match)
    def match(pattern, pos = 0)
      pattern = Regexp.new(pattern.to_s) unless pattern.is_a?(Regexp)
      pattern.match(self, pos)
    end
  end

  unless method_defined?(:match?)
    def match?(pattern, pos = 0)
      pattern = Regexp.new(pattern.to_s) unless pattern.is_a?(Regexp)
      pattern.match?(self, pos)
    end
  end

  unless method_defined?(:scan)
    def scan(pattern)
      pattern = __regexp_coerce(pattern)
      results = []
      pos = 0
      last_match = nil
      while pos <= length
        match = pattern.match(self, pos)
        break unless match

        last_match = match
        value = match.captures.empty? ? match[0] : match.captures
        if block_given?
          yield value
        else
          results << value
        end
        stop = match.end(0)
        pos = stop == match.begin(0) ? stop + 1 : stop
      end
      $~ = last_match
      block_given? ? self : results
    end
  end

  alias_method :__ruflet_string_gsub, :gsub unless method_defined?(:__ruflet_string_gsub)
  def gsub(pattern, replacement = nil, &block)
    unless pattern.is_a?(Regexp)
      return __ruflet_string_gsub(pattern, replacement) unless replacement.nil?

      return __ruflet_string_gsub(pattern, &block)
    end

    out = +""
    pos = 0
    scan_pos = 0
    last_match = nil
    while scan_pos <= length
      match = pattern.match(self, scan_pos)
      break unless match

      last_match = match
      out += byteslice(pos, match.begin(0) - pos).to_s
      out += __regexp_replacement(match, replacement, &block)
      stop = match.end(0)
      if stop == match.begin(0)
        out += byteslice(stop, 1).to_s if stop < length
        scan_pos = stop + 1
        pos = scan_pos
      else
        scan_pos = stop
        pos = stop
      end
    end
    out += byteslice(pos, length - pos).to_s if pos <= length
    $~ = last_match
    last_match.nil? ? dup : out
  end

  alias_method :__ruflet_string_sub, :sub unless method_defined?(:__ruflet_string_sub)
  def sub(pattern, replacement = nil, &block)
    unless pattern.is_a?(Regexp)
      return __ruflet_string_sub(pattern, replacement) unless replacement.nil?

      return __ruflet_string_sub(pattern, &block)
    end

    match = pattern.match(self)
    $~ = match
    return dup unless match

    out = +""
    out += byteslice(0, match.begin(0)).to_s
    out += __regexp_replacement(match, replacement, &block)
    out += byteslice(match.end(0), length - match.end(0)).to_s
    out
  end

  unless method_defined?(:gsub!)
    def gsub!(pattern, replacement = nil, &block)
      result = replacement.nil? ? gsub(pattern, &block) : gsub(pattern, replacement)
      return nil if result == self

      replace(result)
    end
  end

  unless method_defined?(:sub!)
    def sub!(pattern, replacement = nil, &block)
      result = replacement.nil? ? sub(pattern, &block) : sub(pattern, replacement)
      return nil if result == self

      replace(result)
    end
  end

  def __regexp_replacement(match, replacement)
    if replacement.nil?
      return yield(match[0]).to_s if block_given?

      return ""
    end
    if replacement.is_a?(Hash)
      return replacement[match[0]].to_s
    end

    text = replacement.to_s
    out = +""
    index = 0
    while index < text.bytesize
      byte = text.getbyte(index)
      if byte == 92 && index + 1 < text.bytesize # backslash
        next_byte = text.getbyte(index + 1)
        if next_byte >= 48 && next_byte <= 57 # \0..\9
          group = next_byte - 48
          out += match[group].to_s
          index += 2
          next
        elsif next_byte == 38 # \&
          out += match[0].to_s
          index += 2
          next
        elsif next_byte == 92 # \\
          out += "\\"
          index += 2
          next
        elsif next_byte == 107 && text.getbyte(index + 2) == 60 # \k<name>
          stop = index + 3
          stop += 1 while stop < text.bytesize && text.getbyte(stop) != 62
          name = text.byteslice(index + 3, stop - index - 3).to_s
          out += match[name].to_s
          index = stop + 1
          next
        end
      end
      out += [byte].pack("C")
      index += 1
    end
    out
  end
  private :__regexp_replacement

  alias_method :__ruflet_string_split, :split unless method_defined?(:__ruflet_string_split)
  def split(pattern = nil, limit = nil)
    unless pattern.is_a?(Regexp)
      return limit.nil? ? __ruflet_string_split(*[pattern].compact) : __ruflet_string_split(pattern, limit)
    end

    parts = []
    pos = 0
    scan_pos = 0
    while scan_pos <= length
      break if !limit.nil? && limit > 0 && parts.length >= limit - 1

      match = pattern.match(self, scan_pos)
      break unless match

      if match.end(0) == match.begin(0)
        break if scan_pos >= length

        parts << byteslice(pos, match.begin(0) + 1 - pos).to_s if match.begin(0) >= pos
        scan_pos = match.begin(0) + 1
        pos = scan_pos
        next
      end

      parts << byteslice(pos, match.begin(0) - pos).to_s
      match.captures.each { |capture| parts << capture unless capture.nil? }
      scan_pos = match.end(0)
      pos = scan_pos
    end
    parts << byteslice(pos, length - pos).to_s if pos <= length
    if limit.nil? || limit.zero?
      parts.pop while !parts.empty? && parts.last == ""
    end
    parts
  end

  alias_method :__ruflet_string_index, :index unless method_defined?(:__ruflet_string_index)
  def index(pattern, start = 0)
    return __ruflet_string_index(pattern, start) unless pattern.is_a?(Regexp)

    match = pattern.match(self, start)
    match && match.begin(0)
  end

  alias_method :__ruflet_string_slice_op, :[] unless method_defined?(:__ruflet_string_slice_op)
  def [](first, second = (no_second = true))
    if first.is_a?(Regexp)
      match = first.match(self)
      return nil unless match

      return match[no_second ? 0 : second]
    end
    no_second ? __ruflet_string_slice_op(first) : __ruflet_string_slice_op(first, second)
  end
  alias_method :slice, :[]

  alias_method :__ruflet_string_partition, :partition unless method_defined?(:__ruflet_string_partition)
  def partition(pattern)
    return __ruflet_string_partition(pattern) unless pattern.is_a?(Regexp)

    match = pattern.match(self)
    return [dup, "", ""] unless match

    [match.pre_match, match[0], match.post_match]
  end

  alias_method :__ruflet_string_start_with_p, :start_with? unless method_defined?(:__ruflet_string_start_with_p)
  def start_with?(*patterns)
    patterns.each do |pattern|
      if pattern.is_a?(Regexp)
        match = pattern.match(self)
        return true if match && match.begin(0).zero?
      elsif __ruflet_string_start_with_p(pattern)
        return true
      end
    end
    false
  end
end

class Symbol
  unless method_defined?(:match)
    def match(pattern, pos = 0)
      to_s.match(pattern, pos)
    end
  end

  unless method_defined?(:match?)
    def match?(pattern, pos = 0)
      to_s.match?(pattern, pos)
    end
  end

  unless method_defined?(:=~)
    def =~(pattern)
      to_s =~ pattern
    end
  end
end
