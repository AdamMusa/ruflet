# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "fileutils"
require_relative "run_ruby_tests"

# tools/run_ruby_tests.rb decides whether CI's Ruby tests pass, so check that it
# fails a failing file, a file that never ran its tests, and, with --strict, a
# skip nobody allowed. The suites here are real minitest files in a temporary
# directory.
class RunRubyTestsTest < Minitest::Test
  PASSING = <<~RUBY
    require "minitest/autorun"
    class PassingTest < Minitest::Test
      def test_one = assert(true)
      def test_two = assert(true)
    end
  RUBY

  SKIPPING = <<~RUBY
    require "minitest/autorun"
    class SkippingTest < Minitest::Test
      def test_runs = assert(true)
      def test_needs_a_gem = skip("frobnicator is not installed")
    end
  RUBY

  FAILING = <<~RUBY
    require "minitest/autorun"
    class FailingTest < Minitest::Test
      def test_wrong = assert_equal(1, 2)
    end
  RUBY

  # Exits 0 without running anything minitest reports on.
  SILENT = <<~RUBY
    puts "nothing here"
  RUBY

  def test_a_suite_of_passing_files_passes
    runner = run_files({ "a_test.rb" => PASSING, "b_test.rb" => PASSING })

    assert runner.success?
    assert_equal [2, 2], runner.runs.map(&:runs)
    assert_includes @out.string, "== 2 processes, 4 runs, 0 failed, 0 skips"
  end

  def test_a_failing_file_fails_the_run
    runner = run_files({ "a_test.rb" => PASSING, "b_test.rb" => FAILING })

    refute runner.success?
    assert_match(/^FAILED  .*b_test\.rb$/, @out.string)
  end

  def test_a_file_that_prints_no_minitest_summary_fails_the_run
    runner = run_files({ "a_test.rb" => SILENT })

    refute runner.success?
    assert_includes @out.string, "no minitest summary"
  end

  def test_a_file_that_cannot_load_fails_the_run
    runner = run_files({ "a_test.rb" => "require \"no/such/library\"\n" })

    refute runner.success?
  end

  def test_skips_are_named_and_pass_without_strict
    runner = run_files({ "a_test.rb" => SKIPPING }, strict: false)

    assert runner.success?
    assert_match(/^skipped SkippingTest#test_needs_a_gem \(.*a_test\.rb\): frobnicator is not installed$/, @out.string)
  end

  def test_strict_fails_on_a_skip_that_is_not_allowed
    runner = run_files({ "a_test.rb" => SKIPPING }, strict: true)

    refute runner.success?
    assert_equal ["SkippingTest#test_needs_a_gem"], runner.unexpected_skips.map { |_run, skip| skip.test }
    assert_includes @out.string, "1 unexpected skip(s)"
  end

  def test_strict_passes_a_skip_on_the_allow_list
    allowed = { "SkippingTest#test_needs_a_gem" => "CI has no frobnicator" }
    runner = run_files({ "a_test.rb" => SKIPPING }, strict: true, allowed: allowed)

    assert runner.success?
    assert_includes @out.string, "allowed because: CI has no frobnicator"
  end

  def test_main_exits_nonzero_for_an_unknown_suite
    _out, err = capture_io do
      assert_raises(SystemExit) { RufletRubyTests.main(["no_such_suite"]) }
    end
    assert_includes err, "Unknown suite no_such_suite"
  end

  # The allow-list starts empty: CI gives every cross-check what it needs.
  def test_nothing_is_allowed_to_skip_in_ci
    assert_empty RufletRubyTests::ALLOWED_SKIPS
  end

  private

  def run_files(files, strict: true, allowed: {})
    Dir.mktmpdir("run-ruby-tests") do |dir|
      FileUtils.mkdir_p(File.join(dir, "test"))
      files.each { |name, body| File.write(File.join(dir, "test", name), body) }
      suite = RufletRubyTests::Suite.new(name: "sample", dir: dir, pattern: "test/*_test.rb")
      @out = StringIO.new
      runner = RufletRubyTests::Runner.new([suite], strict: strict, out: @out, allowed: allowed)
      runner.run
      runner
    end
  end
end
