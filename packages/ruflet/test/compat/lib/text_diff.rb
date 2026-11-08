# frozen_string_literal: true

module RufletCompat
  # A small pure-Ruby unified diff (Myers), so goldens render identically on
  # every host instead of depending on the platform's diff(1).
  module TextDiff
    CONTEXT = 3
    # Beyond this many lines the edit graph gets large; show a full replacement.
    MAX_LINES = 8000

    module_function

    def unified(old_text, new_text, old_label:, new_label:)
      a = split(old_text)
      b = split(new_text)
      return "" if a == b

      ops = a.length + b.length > MAX_LINES ? replace_all(a, b) : edit_script(a, b)
      out = +"--- #{old_label}\n+++ #{new_label}\n"
      hunks(ops).each do |hunk|
        out << hunk_header(hunk)
        hunk[:ops].each do |kind, line|
          prefix = { eq: " ", del: "-", ins: "+" }.fetch(kind)
          out << prefix << line.chomp << "\n"
          out << "\\ No newline at end of file\n" unless line.end_with?("\n")
        end
      end
      out
    end

    def split(text)
      text.to_s.lines
    end

    def replace_all(a, b)
      a.map { |line| [:del, line] } + b.map { |line| [:ins, line] }
    end

    # Myers' O(ND) shortest edit script, returned as [kind, line] pairs.
    def edit_script(a, b)
      n = a.length
      m = b.length
      max = n + m
      offset = max + 1
      v = Array.new((2 * max) + 3, 0)
      trace = []
      found = false
      (0..max).each do |d|
        trace << v.dup
        (-d..d).step(2) do |k|
          x = if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset])
                v[k + 1 + offset]
              else
                v[k - 1 + offset] + 1
              end
          y = x - k
          while x < n && y < m && a[x] == b[y]
            x += 1
            y += 1
          end
          v[k + offset] = x
          if x >= n && y >= m
            found = true
            break
          end
        end
        break if found
      end
      backtrack(trace, a, b, offset)
    end

    def backtrack(trace, a, b, offset)
      x = a.length
      y = b.length
      ops = []
      (trace.length - 1).downto(0) do |d|
        v = trace[d]
        k = x - y
        prev_k = if k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset])
                   k + 1
                 else
                   k - 1
                 end
        prev_x = v[prev_k + offset]
        prev_y = prev_x - prev_k
        while x > prev_x && y > prev_y
          ops << [:eq, a[x - 1]]
          x -= 1
          y -= 1
        end
        if d.positive?
          if x == prev_x
            ops << [:ins, b[y - 1]]
          else
            ops << [:del, a[x - 1]]
          end
        end
        x = prev_x
        y = prev_y
      end
      ops.reverse
    end

    def hunks(ops)
      a_pos = []
      b_pos = []
      a_line = 0
      b_line = 0
      ops.each do |kind, _line|
        a_pos << a_line
        b_pos << b_line
        a_line += 1 unless kind == :ins
        b_line += 1 unless kind == :del
      end

      changes = ops.each_index.reject { |index| ops[index][0] == :eq }
      ranges = []
      changes.each do |index|
        first = [index - CONTEXT, 0].max
        last = [index + CONTEXT, ops.length - 1].min
        if ranges.any? && first <= ranges.last[1] + 1
          ranges.last[1] = last
        else
          ranges << [first, last]
        end
      end

      ranges.map do |first, last|
        slice = ops[first..last]
        {
          a_start: a_pos[first],
          a_len: slice.count { |kind, _| kind != :ins },
          b_start: b_pos[first],
          b_len: slice.count { |kind, _| kind != :del },
          ops: slice
        }
      end
    end

    def hunk_header(hunk)
      a_start = hunk[:a_len].zero? ? hunk[:a_start] : hunk[:a_start] + 1
      b_start = hunk[:b_len].zero? ? hunk[:b_start] : hunk[:b_start] + 1
      "@@ -#{a_start},#{hunk[:a_len]} +#{b_start},#{hunk[:b_len]} @@\n"
    end
  end
end
