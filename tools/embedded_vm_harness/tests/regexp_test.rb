# Regexp engine regression suite for the embedded Ruflet VM.
# Written so it also runs (and passes) under CRuby — run it there to validate
# the expectations themselves:
#   ruby tools/embedded_vm_harness/tests/regexp_test.rb
#   tools/embedded_vm_harness/build/embedded_mruby --preload \
#     tools/embedded_vm_harness/tests/regexp_test.rb

$failures = []
$tests = 0

def assert_equal(expected, actual, label)
  $tests += 1
  return if expected == actual

  $failures << "#{label}: expected #{expected.inspect}, got #{actual.inspect}"
end

def assert(condition, label)
  $tests += 1
  $failures << label unless condition
end

# -- literals and basic matching ---------------------------------------------
assert_equal(0, /abc/ =~ "abcdef", "literal =~ position")
assert_equal(3, /def/ =~ "abcdef", "literal =~ offset")
assert_equal(nil, /xyz/ =~ "abcdef", "literal no match")
assert(/abc/.match?("zabc"), "match? mid-string")
assert(!/abc/.match?("ab"), "match? failure")
assert_equal("abc", /abc/.match("abc")[0], "MatchData[0]")
assert_equal("b", /a(b)c/.match("abc")[1], "capture 1")
assert_equal(["b", "c"], /a(b)(c)/.match("abc").captures, "captures")
assert_equal("abc", "abc"[/a.c/], "String#[] with regexp")
assert_equal("b", "abc"[/a(.)c/, 1], "String#[] with capture")

# -- character classes & shorthands ------------------------------------------
assert_equal(0, /[abc]+/ =~ "cab", "char class")
assert_equal("123", "abc123def"[/\d+/], "\\d+")
assert_equal("abc", "abc123"[/[a-z]+/], "range class")
assert_equal("ABC", "ABC123"[/[A-Z]+/], "uppercase range")
assert_equal(" \t", "a \tb"[/\s+/], "\\s+")
assert_equal("a_1", "a_1-b"[/\w+/], "\\w+")
assert_equal("-", "a_1-b"[/\W/], "\\W")
assert_equal("xyz", "123xyz"[/\D+/], "\\D+")
assert_equal("q", "123q"[/[^0-9]/], "negated class")
assert_equal("]x", "]x"[/[\]x]+/], "escaped ] in class")
assert_equal("a-b", "a-b"[/[a\-b]+/], "escaped - in class")
assert_equal("3f", "3f"[/\h+/], "hex class")

# -- anchors -------------------------------------------------------------------
assert(/\Aabc/.match?("abc!"), "\\A anchor")
assert(!/\Aabc/.match?("zabc"), "\\A anchor fail")
assert(/abc\z/.match?("zabc"), "\\z anchor")
assert(!/abc\z/.match?("abcz"), "\\z anchor fail")
assert(/^b/.match?("a\nb"), "^ matches line start")
assert(/a$/.match?("a\nb"), "$ matches line end")
assert(/\bword\b/.match?("a word here"), "word boundary")
assert(!/\bord\b/.match?("a word here"), "word boundary fail")

# -- quantifiers ---------------------------------------------------------------
assert_equal("aaa", "aaab"[/a+/], "greedy +")
assert_equal("", "aaab"[/z*/], "zero-width *")
assert_equal("aa", "aaa"[/a{2}/], "{n}")
assert_equal("aaa", "aaaa"[/a{2,3}/], "{n,m}")
assert_equal("aaaa", "aaaa"[/a{2,}/], "{n,}")
assert_equal("a", "aaa"[/a+?/], "lazy +?")
assert_equal("<a>", "<a><b>"[/<.+?>/], "lazy dot")
assert_equal("<a><b>", "<a><b>"[/<.+>/], "greedy dot")
assert_equal("color", "color"[/colou?r/], "optional")
assert_equal("colour", "colour"[/colou?r/], "optional present")
assert_equal("aaa", "aaa"[/a{1,}?a{2}/], "lazy then fixed backtrack")

# -- groups, alternation, backrefs ---------------------------------------------
assert_equal("cat", "cat"[/cat|dog/], "alternation 1")
assert_equal("dog", "dog"[/cat|dog/], "alternation 2")
assert_equal("ab", "ab"[/(?:a|x)b/], "non-capturing group")
m = /(\d+)-(\d+)/.match("10-20")
assert_equal(["10", "20"], m.captures, "multi capture")
assert_equal(0, m.begin(0), "begin 0")
assert_equal(2, m.begin(2) - m.begin(1) - 1, "capture positions")
assert_equal("aa", "aa"[/(a)\1/], "backreference")
assert_equal(nil, "ab"[/(a)\1/], "backreference fail")
m = /(?<year>\d{4})-(?<month>\d{2})/.match("2026-06-10")
assert_equal("2026", m[:year], "named capture symbol")
assert_equal("06", m["month"], "named capture string")
assert_equal({"year" => "2026", "month" => "06"}, m.named_captures, "named_captures")
assert_equal("2026", /(?<y>\d+)/.match("2026")[:y], "short named capture")
assert_equal("ab", "ab"[/(a)(b)?\2?/], "optional group no backref crash")

# -- options -------------------------------------------------------------------
assert(/abc/i.match?("ABC"), "ignorecase literal")
assert(/[a-z]+/i.match?("XYZ"), "ignorecase class")
assert_equal("A\nB", "A\nB"[/a.b/im], "multiline dot")
assert_equal(nil, "A\nB"[/A.B/], "dot does not cross newline")
assert(/a b/x.match?("ab"), "extended ignores spaces")
assert(Regexp.new("abc", Regexp::IGNORECASE).match?("AbC"), "Regexp.new with int options")
assert(Regexp.new("abc", "i").match?("AbC"), "Regexp.new with string options")

# -- lookahead -----------------------------------------------------------------
assert_equal("foo", "foobar"[/foo(?=bar)/], "positive lookahead")
assert_equal(nil, "foobaz"[/foo(?=bar)/], "positive lookahead fail")
assert_equal("foo", "foobaz"[/foo(?!bar)/], "negative lookahead")
assert_equal(nil, "foobar"[/foo(?!bar)/], "negative lookahead fail")

# -- MatchData extras ----------------------------------------------------------
m = /b(c)/.match("abcd")
assert_equal("a", m.pre_match, "pre_match")
assert_equal("d", m.post_match, "post_match")
assert_equal(["bc", "c"], m.to_a, "to_a")
assert_equal("bc", m.to_s, "to_s")
assert_equal([1, 3], m.offset(0), "offset")
assert_equal(2, m.size, "size")
m = /x/.match("zxz")
assert_equal(m[0], Regexp.last_match(0), "Regexp.last_match")
assert_equal(m[0], $~[0], "$~ set")

# -- String integration --------------------------------------------------------
assert_equal(["12", "34"], "a12b34".scan(/\d+/), "scan plain")
assert_equal([["1", "2"], ["3", "4"]], "12 34".scan(/(\d)(\d)/), "scan captures")
assert_equal("X-X-X", "a-b-c".gsub(/[abc]/, "X"), "gsub regexp")
assert_equal("a1c", "abc".sub(/b/, "1"), "sub regexp")
assert_equal("h*ll*", "hello".gsub(/[eo]/, "*"), "gsub class")
assert_equal("he[l][l]", "hell".gsub(/l/) { |c| "[#{c}]" }, "gsub block")
assert_equal("he..o", "hello".gsub(/l/, "."), "gsub single char")
assert_equal("xbc", "abc".sub(/a/) { "x" }, "sub block")
assert_equal("a<b>c", "abc".sub(/(b)/, "<\\1>"), "sub backref replacement")
assert_equal("cba", "abc".gsub(/(a)(b)(c)/, "\\3\\2\\1"), "gsub numbered backrefs")
assert_equal("&amp;", "&".gsub(/&/, "&amp;"), "gsub literal amp")
assert_equal(["a", "b", "c"], "a1b2c".split(/\d/), "split regexp")
assert_equal(["a", "b,c"], "a,b,c".split(/,/, 2), "split with limit")
assert_equal(["", "b"], "ab".split(/a/), "split leading empty")
assert_equal(2, "hello".index(/l/), "index regexp")
assert_equal(["he", "ll", "o"], "hello".partition(/ll/), "partition regexp")
assert_equal(6, ("hello world" =~ /world/), "String#=~")
assert(:abc.match?(/b/), "Symbol#match?")
assert("path/to".start_with?(/pa/), "start_with? regexp")
assert(!"path/to".start_with?(/to/), "start_with? regexp no match")

# -- case/when and ===
result = case "production"
         when /\Adev/ then "dev"
         when /\Aprod/ then "prod"
         else "other"
         end
assert_equal("prod", result, "case/when regexp")

# -- Regexp.escape / union -----------------------------------------------------
assert(Regexp.new(Regexp.escape("a.b*c")).match?("a.b*c"), "escape round trip")
assert(!Regexp.new(Regexp.escape("a.b")).match?("axb"), "escape disables meta")
assert(Regexp.union("cat", "dog").match?("hotdog"), "union")
assert_equal("/ab/i", /ab/i.inspect, "inspect")
assert_equal("ab", /ab/i.source, "source")
assert(/ab/i.casefold?, "casefold?")

# -- real-world patterns -------------------------------------------------------
assert("2026-06-10".match?(/\A\d{4}-\d{2}-\d{2}\z/), "ISO date")
assert("-12.5".match?(/\A-?\d+(\.\d+)?\z/), "showcase numeric guard")
assert(!"12.".match?(/\A-?\d+(\.\d+)?\z/), "showcase numeric guard reject")
assert_equal("showcase/x.rb", "/showcase/x.rb".sub(%r{^/}, ""), "showcase path strip")
assert_equal("x.rb", "showcase/x.rb".sub(%r{\Ashowcase/}, ""), "showcase prefix strip")
email = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
assert(email.match?("user.name+tag@example.co.uk"), "email pattern accept")
assert(!email.match?("not an email"), "email pattern reject")
assert_equal("1,234,567", "1234567".reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse, "thousands separators")
hex_color = /\A#(?<r>\h{2})(?<g>\h{2})(?<b>\h{2})\z/
m = hex_color.match("#1a2b3c")
assert_equal(["1a", "2b", "3c"], [m[:r], m[:g], m[:b]], "hex color named groups")
assert_equal(["key", "value"], "key=value".match(/(\w+)=(\w+)/).captures, "key=value")
words = "The quick brown fox".scan(/\w+/)
assert_equal(4, words.length, "word scan")
assert_equal("The_quick_brown_fox", "The quick brown fox".gsub(/\s+/, "_"), "whitespace collapse")
camel = "snake_case_name".gsub(/_([a-z])/) { Regexp.last_match(1).upcase }
assert_equal("snakeCaseName", camel, "snake to camel via last_match")

# -- report --------------------------------------------------------------------
if $failures.empty?
  puts "PASS: #{$tests} assertions"
else
  puts "FAIL: #{$failures.length} of #{$tests} assertions failed"
  $failures.each { |failure| puts "  - #{failure}" }
  raise "regexp test failures"
end
