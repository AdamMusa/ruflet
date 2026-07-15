# Standard-Ruby compatibility regression suite for the embedded Ruflet VM.
#
# Run with the desktop harness, which compiles the exact mruby sources the
# Flutter plugins ship:
#
#   tools/embedded_vm_harness/build.sh
#   tools/embedded_vm_harness/build/embedded_mruby --preload \
#     tools/embedded_vm_harness/tests/compat_test.rb
#
# Keep this file valid mruby (no CRuby-only syntax). Regexp coverage lives in
# regexp_test.rb.

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

def assert_raises(klass, label)
  $tests += 1
  yield
  $failures << "#{label}: nothing raised"
rescue Exception => e
  $failures << "#{label}: raised #{e.class} (#{e.message})" unless e.is_a?(klass)
end

# -- Core constants -----------------------------------------------------------
%w[
  Comparable Enumerable Enumerator Fiber Set Struct Data Time Math Random
  Mutex Thread Process Signal Dir File IO Socket TCPServer JSON Digest
  SecureRandom FileUtils CGI StringIO OpenStruct Forwardable Base64 ENV ARGV
  SystemExit StopIteration KeyError FrozenError Errno LoadError Interrupt
].each do |name|
  assert(Object.const_defined?(name), "constant #{name} should be defined")
end

# -- Object / Kernel ----------------------------------------------------------
assert_equal(5, 5.itself, "Object#itself")
assert_equal(6, 5.then { |v| v + 1 }, "Object#then")
assert_equal(6, 5.yield_self { |v| v + 1 }, "Object#yield_self")
assert_equal([2], [2].tap { |v| v.first }, "Object#tap")
assert_equal(8, 5.method(:+).call(3), "Object#method -> Method#call")
assert_equal(3, 5.instance_eval { self - 2 }, "instance_eval block")
assert_equal(7, 5.instance_exec(2) { |n| self + n }, "instance_exec")
assert_equal(3, eval("1 + 2"), "Kernel#eval")
assert_equal("05", format("%02d", 5), "Kernel#format")
assert_equal("a-1", sprintf("%s-%d", "a", 1), "Kernel#sprintf")
assert_equal(42, catch(:tag) { throw :tag, 42 }, "catch/throw with value")
assert_equal(7, catch(:t) { 7 }, "catch without throw")
assert(rand.is_a?(Float) && rand < 1.0, "rand() returns Float < 1")
assert(rand(10).is_a?(Integer), "rand(n) returns Integer")
assert(rand(5..6) >= 5, "rand(range)")
srand(1234)
first_roll = rand(1_000_000)
srand(1234)
assert_equal(first_roll, rand(1_000_000), "srand reseeds deterministically")
assert_equal(293, Random.new(42).rand(1000), "Random.new(seed)")
assert_raises(SystemExit, "exit raises SystemExit") { exit }
assert_raises(SystemExit, "exit(2) raises SystemExit") { exit(2) }
assert_equal(2, (begin; exit(2); rescue SystemExit => e; e.status; end), "SystemExit#status")
assert_equal(1, pp(1), "Kernel#pp returns argument")
assert_equal([], caller, "Kernel#caller") if Kernel.private_method_defined?(:caller)
assert_equal(3, Integer("3"), "Kernel#Integer")
assert_equal(255, Integer("0xff", 16), "Kernel#Integer base") rescue assert(Integer("ff", 16) == 255, "Kernel#Integer base 16")
assert_equal(1.5, Float("1.5"), "Kernel#Float")
assert_equal("5", String(5), "Kernel#String")
assert_equal([5], Array(5), "Kernel#Array")

# -- Comparable ---------------------------------------------------------------
assert_equal(5, 7.clamp(1, 5), "Integer#clamp")
assert_equal(2.5, 2.5.clamp(1.0, 5.0), "Float#clamp")
assert(3.between?(1, 5), "Integer#between?")

# -- Enumerable / Enumerator --------------------------------------------------
data = [3, 1, 2, 2, 5]
assert_equal([1, 2, 2, 3, 5], data.sort, "Array#sort")
assert_equal([3, 1, 5], data.select(&:odd?), "select with symbol proc")
assert_equal([3, 1, 5], data.filter(&:odd?), "Array#filter")
assert_equal(13, data.sum, "Array#sum")
assert_equal(13, data.reduce(:+), "reduce with symbol")
assert_equal(2, data.min_by { |v| (v - 2).abs }, "min_by")
assert_equal(5, data.max_by { |v| v }, "max_by")
assert_equal({ 3 => 1, 1 => 1, 2 => 2, 5 => 1 }, data.tally, "tally")
assert_equal([[3], [1, 2, 2, 5]], data.chunk_while { |a, b| a <= b }.to_a, "chunk_while")
assert_equal([[3], [1, 2, 2, 5]], data.slice_when { |a, b| a > b }.to_a, "slice_when")
assert_equal([[3, 1], [2, 2], [5]], data.each_slice(2).to_a, "each_slice")
assert_equal([[3, 1], [1, 2], [2, 2], [2, 5]], data.each_cons(2).to_a, "each_cons")
assert_equal([6, 10], data.filter_map { |v| v * 2 if v > 2 }, "filter_map")
assert_equal({ true => [3, 5], false => [1, 2, 2] }, data.group_by { |v| v > 2 }, "group_by")
assert_equal([[3, 5], [1, 2, 2]], data.partition { |v| v > 2 }, "partition")
assert_equal([3, 1, 2, 5], data.uniq, "uniq")
assert_equal([[3, "a"], [1, "b"]], [3, 1].zip(%w[a b]), "zip")
assert_equal([3, 1], data.take(2), "take")
assert_equal([2, 2, 5], data.drop(2), "drop")
assert_equal([3, 1], data.take_while(&:odd?), "take_while")
assert_equal(15, (1..5).sum, "Range#sum")
assert_equal([1, 3, 5], (1..5).step(2).to_a, "Range#step")
assert_equal([1, 3, 5], 1.step(5, 2).to_a, "Numeric#step")
assert_equal([2, 4], (1..5).lazy.map { |v| v * 2 }.select(&:even?).first(2), "lazy enumerator")
enum = [10, 20].each_with_index
assert(enum.is_a?(Enumerator), "each_with_index without block returns Enumerator")
assert_equal([10, 0], enum.next, "Enumerator#next")
assert_equal([[10, 0], [20, 1]], [10, 20].each_with_index.to_a, "Enumerator#to_a")
assert_equal({ a: 1 }, [[:a, 1]].to_h, "Array#to_h")
assert_equal([1, 2, 3, 4], [[1, 2], [3, 4]].flat_map { |pair| pair }, "flat_map")
assert_equal(3, (1..Float::INFINITY).lazy.select(&:odd?).first(2).last, "infinite lazy") if Float.const_defined?(:INFINITY)

# -- Array --------------------------------------------------------------------
arr = [1, 2, 3]
assert_equal([3, 2, 1], arr.reverse, "Array#reverse")
assert_equal([1, 2], [1, 2, 2].uniq, "Array#uniq")
assert_equal([2], [1, 2] & [2, 3], "Array#&")
assert_equal([1, 2, 3], [1, 2] | [2, 3], "Array#|")
assert_equal([1], [1, 2] - [2], "Array#-")
assert_equal([1, 2, 2, 3], ([1, 2] + [2, 3]), "Array#+")
assert_equal([1, 2, 3], [1, [2, [3]]].flatten, "flatten")
assert_equal([1, 2, [3]], [1, [2, [3]]].flatten(1), "flatten with depth")
assert_equal(2, [1, 2, 3].dig(1), "Array#dig")
assert_equal(6, [[1, [2, 6]]].dig(0, 1, 1), "Array#dig nested")
assert_equal([2, 3, 1], arr.rotate, "rotate")
assert_equal([1, 4, 9], arr.map { |v| v * v }, "map")
assert_equal([[1, 3], [2, 4]], [[1, 2], [3, 4]].transpose, "transpose")
assert_equal([1, 2], [nil, 1, nil, 2].compact, "compact")
assert_equal(3, arr.last, "last")
assert_equal([2, 3], arr.last(2), "last(n)")
assert_equal([1, 3], arr.values_at(0, 2), "values_at")
assert_equal([[1, 2], [1, 3], [2, 3]], [1, 2, 3].combination(2).to_a, "combination")
assert_equal(6, [1, 2, 3].permutation(3).to_a.length, "permutation")
assert_equal([[1, :a], [1, :b], [2, :a], [2, :b]], [1, 2].product([:a, :b]), "product")
assert_equal(2, [1, 2, 3].bsearch { |v| v >= 2 }, "bsearch")
assert(arr.sample(100) || true, "sample does not raise")
assert_equal(3, [1, 2, 3].shuffle.length, "shuffle")
assert_equal([3, 2, 1], arr.sort_by { |v| -v }, "sort_by")
assert_equal("1-2-3", arr.join("-"), "join")
assert_equal([1, 2, 3, 4], arr.dup.push(4), "push")
assert_equal(1, [[1, "one"]].assoc(1)[0], "assoc")

# -- Hash ---------------------------------------------------------------------
hash = { a: 1, b: 2, c: 3 }
assert_equal({ a: 1 }, hash.slice(:a), "Hash#slice")
assert_equal({ b: 2, c: 3 }, hash.except(:a), "Hash#except")
assert_equal({ a: 2, b: 4, c: 6 }, hash.transform_values { |v| v * 2 }, "transform_values")
assert_equal({ "a" => 1, "b" => 2, "c" => 3 }, hash.transform_keys(&:to_s), "transform_keys")
assert_equal({ a: 1, b: 2 }, hash.select { |_k, v| v < 3 }, "Hash#select returns Hash")
assert_equal({ c: 3 }, hash.reject { |_k, v| v < 3 }, "Hash#reject")
assert_equal(6, hash.sum { |_k, v| v }, "Hash#sum")
assert_equal(2, hash.dig(:b), "Hash#dig")
assert_equal({ 1 => :a, 2 => :b, 3 => :c }, hash.invert, "invert")
assert_equal(:b, hash.key(2), "Hash#key")
assert_equal([1, 2], hash.fetch_values(:a, :b), "fetch_values")
assert_equal({ a: 1, b: 2, c: 3, d: 4 }, hash.merge(d: 4), "merge")
assert_equal(99, hash.fetch(:zz) { 99 }, "fetch with block")
assert_equal({ a: 1 }, { a: 1, b: nil }.compact, "Hash#compact")
assert_equal([:a, 1], hash.first, "Hash#first")
assert_equal({ a: 2 }, { a: 1 }.merge({ a: 1 }) { |_k, old, new| old + new }, "merge with block")
assert_equal({ b: 2 }, hash.filter { |_k, v| v == 2 }, "Hash#filter")
assert(hash.any? { |_k, v| v > 2 }, "Hash#any?")
assert_equal(3, hash.count, "Hash#count")
assert_equal([[:a, 1], [:b, 2], [:c, 3]], hash.to_a, "Hash#to_a")

# -- String -------------------------------------------------------------------
text = "hello world"
assert_equal("Hello world", text.capitalize, "capitalize")
assert_equal("HELLO WORLD", text.upcase, "upcase")
assert_equal(%w[hello world], text.split(" "), "split")
assert_equal("hello", text[0, 5], "slice")
assert_equal("dlrow olleh", text.reverse, "reverse")
assert_equal("hello***", "hello".ljust(8, "*"), "ljust")
assert_equal("***hello", "hello".rjust(8, "*"), "rjust")
assert_equal("*hello**", "hello".center(8, "*"), "center")
assert_equal(%w[h e l l o], "hello".chars, "chars")
assert_equal("ello", "hello".delete("h"), "delete")
assert_equal("heo", "hello".delete("l"), "delete repeated")
assert_equal("helo", "hello".squeeze, "squeeze")
assert_equal("ifmmp", "hello".tr("a-y", "b-z"), "tr with ranges")
assert_equal(2, "hello".count("l"), "count")
assert_equal("hff", "hello".squeeze.tr("el", "f").delete("o"), "chained string ops")
assert_equal("abc", "  abc  ".strip, "strip")
assert_equal("abc  ", "  abc  ".lstrip, "lstrip")
assert_equal("  abc", "  abc  ".rstrip, "rstrip")
assert_equal("ab", "abc".chop, "chop")
assert_equal("abc", "abc\n".chomp, "chomp")
assert_equal("abd", "abc".succ, "succ")
assert_equal("ad", "ac".next, "next")
assert_equal(97, "a".ord, "ord")
assert_equal("a", 97.chr, "Integer#chr")
assert_equal(255, "ff".hex, "hex")
assert_equal(8, "010".oct, "oct")
assert_equal(["he", "l", "lo"], "hello".partition("l"), "partition")
assert_equal(["hel", "l", "o"], "hello".rpartition("l"), "rpartition")
assert_equal("olleh", "hello".each_char.to_a.reverse.join, "each_char")
assert_equal(2, "a\nb\n".lines.length, "lines")
assert_equal("b", "abc"[1, 1], "string index")
assert_equal("hello", "hel" + "lo", "concat")
assert_equal("hellohello", "hello" * 2, "repeat")
assert_equal("h*llo", "hello".sub("e", "*"), "sub")
assert_equal("h*ll*", "hello".gsub("e", "*").gsub("o", "*"), "gsub")
assert_equal(true, "hello".start_with?("he", "xx"), "start_with multiple")
assert_equal(true, "hello".end_with?("lo"), "end_with")
assert_equal("HELLO", "hello".swapcase, "swapcase")
assert_equal(0, "abc".casecmp("ABC"), "casecmp")
assert_equal(true, "abc".casecmp?("ABC"), "casecmp?")
assert_equal("abc", "abc".encode("UTF-8"), "encode no-op")
assert_equal("a-b", %w[a b].join("-"), "join")
assert_equal("123", "0123".delete_prefix("0"), "delete_prefix")
assert_equal("012", "0123".delete_suffix("3"), "delete_suffix")
assert_equal("b", "abc".byteslice(1, 1), "byteslice")
assert_equal(3, "abc".bytesize, "bytesize")
assert_equal("YWJj", ["abc"].pack("m0"), "pack base64")
assert_equal("abc", "YWJj".unpack1("m"), "unpack1 base64")

# -- Integer / Float / Math ---------------------------------------------------
assert_equal(2, 10.gcd(4), "gcd")
assert_equal(20, 10.lcm(4), "lcm")
assert_equal([2, 20], 10.gcdlcm(4), "gcdlcm")
assert_equal([3, 2, 1], 123.digits, "digits")
assert_equal(24, 2.pow(10, 1000), "pow with modulus")
assert_equal(1024, 2**10, "**")
assert_equal(1, 5[0], "Integer#[] bit")
assert_equal(6, 5.pred.succ.succ, "pred/succ")
assert(4.even? && 5.odd?, "even?/odd?")
assert_equal(8, 5.bit_length.succ.succ.succ.succ.succ, "bit_length")
assert_equal(3, 10.fdiv(3).round, "fdiv")
assert_equal([3, 1], 10.divmod(3), "divmod")
assert((Math.sqrt(2) - 1.41421356).abs < 0.0001, "Math.sqrt")
assert((Math::PI - 3.14159265).abs < 0.0001, "Math::PI")
assert((Math.sin(Math::PI / 2) - 1.0).abs < 0.0001, "Math.sin")
assert((Math.log10(100) - 2.0).abs < 0.0001, "Math.log10")
assert((Math.cbrt(27) - 3.0).abs < 0.0001, "Math.cbrt")
assert_equal(1.5, 1.45.round(1), "Float#round digits")
assert_equal(1, 1.9.floor, "floor")
assert_equal(2, 1.1.ceil, "ceil")
assert(1.0.finite?, "finite?")
assert((1.0 / 0).infinite? == 1, "infinite?")
assert((0.0 / 0.0).nan?, "nan?")
assert_equal([2.0, 1.0], 1.0.coerce(2), "Float#coerce")
assert_equal([2, 1], 1.coerce(2), "Integer#coerce")

# -- Symbol / Proc / Method ---------------------------------------------------
assert_equal("a", :abc[0], "Symbol#[]")
assert(:abc.start_with?("a"), "Symbol#start_with?")
assert(:abc.end_with?("c"), "Symbol#end_with?")
assert_equal(:abd, :abc.succ, "Symbol#succ")
assert_equal(:ABC, :abc.upcase, "Symbol#upcase")
assert_equal(3, :abc.length, "Symbol#length")
double = proc { |v| v * 2 }
assert_equal(4, double.call(2), "proc")
assert_equal(4, double[2], "Proc#[]")
assert_equal(4, double.(2), "Proc#call shorthand")
add = lambda { |a, b| a + b }
assert(add.lambda?, "lambda?")
assert_equal(2, add.arity, "arity")
curried = add.curry
assert_equal(3, curried[1][2], "curry")
composed = double >> proc { |v| v + 1 }
assert_equal(5, composed.call(2), "Proc#>>")
m = 5.method(:+)
assert_equal(:+, m.name, "Method#name")
assert_equal(8, m.to_proc.call(3), "Method#to_proc")
assert_equal([1, 2].map(&:to_s), %w[1 2], "Symbol#to_proc")

# -- Struct / Data / Set / OpenStruct ----------------------------------------
point_class = Struct.new(:x, :y) do
  def magnitude
    Math.sqrt((x * x + y * y).to_f)
  end
end
point = point_class.new(3, 4)
assert_equal(3, point.x, "Struct accessor")
assert_equal(5.0, point.magnitude, "Struct custom method")
assert_equal([3, 4], point.to_a, "Struct#to_a")
assert_equal({ x: 3, y: 4 }, point.to_h, "Struct#to_h")
point.x = 6
assert_equal(6, point.x, "Struct setter")
kw_struct = Struct.new(:a, :b, keyword_init: true)
assert_equal(1, kw_struct.new(a: 1, b: 2).a, "Struct keyword_init")

coords = Data.define(:lat, :lng)
spot = coords.new(lat: 1.5, lng: 2.5)
assert_equal(1.5, spot.lat, "Data accessor")
assert_equal({ lat: 1.5, lng: 2.5 }, spot.to_h, "Data#to_h")

set = Set.new([1, 2, 2, 3])
assert_equal(3, set.size, "Set#size")
assert(set.include?(2), "Set#include?")
set << 4
assert_equal(4, set.size, "Set#<<")
assert((Set.new([1, 2]) & Set.new([2, 3])).include?(2), "Set#&")
assert(Set.new([1]).subset?(Set.new([1, 2])), "Set#subset?")
assert_equal([2, 4], [1, 2, 3, 4].to_set.select(&:even?).sort, "to_set")

person = OpenStruct.new(name: "Ada")
assert_equal("Ada", person.name, "OpenStruct reader")
person.age = 36
assert_equal(36, person.age, "OpenStruct writer")
assert_equal({ name: "Ada", age: 36 }, person.to_h, "OpenStruct#to_h")
assert(person.respond_to?(:name), "OpenStruct respond_to?")

# -- Time ---------------------------------------------------------------------
now = Time.now
assert(now.year >= 2026, "Time.now year")
assert(now.to_f > 1_700_000_000.0, "Time.now epoch")
epoch = Time.at(0).utc
assert_equal(1970, epoch.year, "Time.at(0)")
assert_equal("1970-01-01", epoch.strftime("%Y-%m-%d"), "strftime date")
assert_equal("00:00:00", epoch.strftime("%H:%M:%S"), "strftime time")
assert_equal("Thursday", epoch.strftime("%A"), "strftime weekday")
assert_equal("1970-01-01T00:00:00+00:00", epoch.iso8601, "iso8601")
later = now + 60
assert_equal(60, (later - now).to_i, "Time arithmetic")
assert(Time.utc(2024, 6, 1).utc?, "Time.utc")
assert_equal(0, Process.clock_gettime(Process::CLOCK_MONOTONIC, :second) - Time.now.to_i, "clock_gettime seconds")

# -- JSON ---------------------------------------------------------------------
parsed = JSON.parse('{"a": [1, 2.5, true, null], "b": "text"}')
assert_equal([1, 2.5, true, nil], parsed["a"], "JSON.parse array")
assert_equal("text", parsed["b"], "JSON.parse string")
generated = JSON.generate({ "x" => [1, true, nil], "y" => "a\"b" })
assert_equal('{"x":[1,true,null],"y":"a\"b"}', generated, "JSON.generate")
assert_equal(generated, JSON.parse(generated).to_json, "JSON round trip")
assert_equal('{"sym":"v"}', { sym: "v" }.to_json, "Hash#to_json symbol keys")
assert_equal("[1,2]", [1, 2].to_json, "Array#to_json")
assert(JSON.pretty_generate({ "a" => 1 }).include?("\n"), "pretty_generate")

# -- StringIO -----------------------------------------------------------------
io = StringIO.new
io.puts "line1"
io.write("line2")
io.rewind
assert_equal("line1\n", io.gets, "StringIO#gets")
assert_equal("line2", io.read, "StringIO#read")
assert(io.eof?, "StringIO#eof?")
io.rewind
assert_equal(%W[line1\n line2], io.readlines, "StringIO#readlines")
assert_equal("line1\nline2", io.string, "StringIO#string")

# -- Files / Dir / FileUtils --------------------------------------------------
base = Dir.tmpdir + "/ruflet_compat_test_#{Process.respond_to?(:pid) ? Process.pid : rand(99_999)}"
FileUtils.rm_rf(base)
FileUtils.mkdir_p(base + "/nested/deep")
assert(File.directory?(base + "/nested/deep"), "mkdir_p")
file_path = base + "/sample.txt"
File.write(file_path, "hello file")
assert_equal("hello file", File.read(file_path), "File.write/read")
assert_equal("hello file", File.binread(file_path), "File.binread")
File.binwrite(file_path + ".bin", "\x01\x02")
assert_equal(2, File.binread(file_path + ".bin").bytesize, "File.binwrite")
assert(File.mtime(file_path).is_a?(Time) || File.mtime(file_path).is_a?(Integer), "File.mtime")
assert_equal([base, "sample.txt"], File.split(file_path), "File.split")
assert_equal("file", File.ftype(file_path), "File.ftype")
entries = Dir.entries(base).sort
assert(entries.include?("sample.txt"), "Dir.entries")
found = Dir.glob(base + "/*.txt") rescue nil
assert(found.nil? || found.length == 1, "Dir.glob optional")
FileUtils.cp(file_path, base + "/copy.txt")
assert_equal("hello file", File.read(base + "/copy.txt"), "FileUtils.cp")
FileUtils.mv(base + "/copy.txt", base + "/moved.txt")
assert(File.exist?(base + "/moved.txt"), "FileUtils.mv")
FileUtils.rm_f(base + "/moved.txt")
assert(!File.exist?(base + "/moved.txt"), "FileUtils.rm_f")
FileUtils.rm_rf(base)
assert(!File.directory?(base), "FileUtils.rm_rf")

# -- SecureRandom / Digest / Base64 ------------------------------------------
hex = SecureRandom.hex(8)
assert_equal(16, hex.length, "SecureRandom.hex length")
assert(hex != SecureRandom.hex(8), "SecureRandom.hex uniqueness")
uuid = SecureRandom.uuid
assert_equal(36, uuid.length, "uuid length")
assert_equal("4", uuid[14, 1], "uuid version 4")
assert_equal(16, SecureRandom.random_bytes(16).bytesize, "random_bytes")
assert_equal(20, Digest::SHA1.digest("abc").bytesize, "Digest::SHA1")
assert_equal("aGVsbG8=", Base64.strict_encode64("hello"), "Base64 encode")
assert_equal("hello", Base64.strict_decode64("aGVsbG8="), "Base64 decode")
assert_equal("hello", Base64.urlsafe_decode64(Base64.urlsafe_encode64("hello")), "Base64 urlsafe")

# -- Exceptions ---------------------------------------------------------------
begin
  raise KeyError, "missing"
rescue KeyError => e
  assert_equal("missing", e.message, "KeyError message")
  assert(e.full_message.include?("KeyError"), "full_message")
  assert_equal(nil, e.cause, "cause")
end
assert_raises(FrozenError, "FrozenError on frozen mutation") { "frozen".freeze << "x" }
assert_raises(StopIteration, "StopIteration") { [].each_with_index.next }
assert_raises(LoadError, "require unknown raises LoadError") { require "definitely_not_bundled" }
assert(require("json") && require("set") && require("time") && require("stringio") && require("ostruct"), "bundled requires")

# -- Misc ---------------------------------------------------------------------
assert_equal("low", (1 <=> 2) == -1 ? "low" : "high", "spaceship")
assert(1.0.display.nil? || true, "display does not raise")
sleep_start = Time.now.to_f
sleep(0.02)
assert(Time.now.to_f - sleep_start >= 0.01, "sleep actually sleeps")
m = Mutex.new
assert_equal(5, m.synchronize { 5 }, "Mutex#synchronize")

class ForwardableHost
  extend Forwardable
  def_delegators :@items, :size, :first

  def initialize(items)
    @items = items
  end
end
host = ForwardableHost.new([9, 8])
assert_equal(2, host.size, "Forwardable def_delegators")
assert_equal(9, host.first, "Forwardable delegation")

# -- Report -------------------------------------------------------------------
if $failures.empty?
  puts "PASS: #{$tests} assertions"
else
  puts "FAIL: #{$failures.length} of #{$tests} assertions failed"
  $failures.each { |failure| puts "  - #{failure}" }
  raise "compat test failures"
end
