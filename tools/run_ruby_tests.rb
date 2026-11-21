#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs Ruflet's Ruby test suites the way CI does (.github/workflows/ruby-tests.yml).
#
#   ruby tools/run_ruby_tests.rb                      # every suite
#   ruby tools/run_ruby_tests.rb ruflet_rails tools   # some of them
#   ruby tools/run_ruby_tests.rb --strict ruflet_core # fail on an unexpected skip
#   ruby tools/run_ruby_tests.rb --list               # suites and their files
#
# A package with a Gemfile runs under it, so `bundle install` in that package
# first. The Gemfiles declare the test toolchain (minitest, minitest-mock) and
# the gems the cross-checks need.
#
# The core packages run one process per test file. ruflet/hot_reload requires
# ruflet_core, whose Kernel#method_missing turns any missing-method call in the
# process into a control object, including inside Process::Waiter threads, so
# loading every file together leaks across suites. ruflet_rails and
# ruflet_record run their own Rakefile's test task.
#
# Every skipped test is listed by name at the end. With --strict, a skip that
# is not in ALLOWED_SKIPS fails the run. CI provides everything the
# cross-checks ask for (a ruflet-engine checkout, the pinned mruby, nokogiri,
# bootsnap, railties, sqlite3), so a skip there means a check quietly stopped
# running.

require "open3"
require "rbconfig"

module RufletRubyTests
  ROOT = File.expand_path("..", __dir__)

  # dir: where the suite runs, relative to ROOT. pattern: its test files,
  # relative to dir. rake: run `rake test` there instead of one process per file.
  Suite = Struct.new(:name, :dir, :pattern, :rake, keyword_init: true) do
    def root = File.expand_path(dir, ROOT)
    def gemfile = File.join(root, "Gemfile")
    def bundled? = File.file?(gemfile)
    # A gem's tests run with its lib/ and test/ on the load path, as CI ran them.
    def gem? = !Dir.glob("*.gemspec", base: root).empty?
    def files = Dir.glob(pattern, base: root).sort
  end

  SUITES = [
    Suite.new(name: "ruflet_core", dir: "packages/ruflet_core", pattern: "test/*_test.rb"),
    Suite.new(name: "ruflet_server", dir: "packages/ruflet_server", pattern: "test/*_test.rb"),
    Suite.new(name: "ruflet", dir: "packages/ruflet", pattern: "test/*_test.rb"),
    Suite.new(name: "ruflet_rails", dir: "packages/ruflet_rails", pattern: "test/**/*_test.rb", rake: true),
    Suite.new(name: "ruflet_record", dir: "packages/ruflet_record", pattern: "test/**/*_test.rb", rake: true),
    Suite.new(name: "ruby_runtime", dir: "ruby_runtime", pattern: "test/*_test.rb"),
    Suite.new(name: "tools", dir: ".", pattern: "tools/*_test.rb")
  ].freeze

  # "Class#test_name" => why CI cannot run it. Keep this empty unless a check
  # truly cannot run on the CI host; give the reason.
  ALLOWED_SKIPS = {}.freeze

  SUMMARY = /^(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/
  # --show-skips prints each skip as "  N) Skipped:\nClass#test [file:line]:\nmessage".
  SKIPPED = /^\s*\d+\) Skipped:\n(?<test>.+?) \[(?<location>[^\]\n]+)\]:\n(?<message>[^\n]*)/

  Skip = Struct.new(:test, :location, :message, keyword_init: true)

  # One test process: a file of a per-file suite, or a suite's `rake test`.
  class Run
    attr_reader :label, :status, :output

    def initialize(label, status, output)
      @label = label
      @status = status
      @output = output
    end

    def summary
      @summary ||= output.scan(SUMMARY).last&.map(&:to_i)
    end

    def runs = summary ? summary[0] : 0
    def skip_count = summary ? summary[4] : 0

    def skips
      @skips ||= output.scan(SKIPPED).map { |test, location, message| Skip.new(test: test, location: location, message: message) }
    end

    # A process that exits 0 without a minitest summary did not run its tests
    # (it stopped before autorun, or printed nothing minitest wrote).
    def failed?
      !status.success? || summary.nil? || summary[2].positive? || summary[3].positive?
    end

    # Skips the summary counted but --show-skips did not name.
    def unnamed_skips = [skip_count - skips.length, 0].max
  end

  class Runner
    attr_reader :runs

    def initialize(suites, strict:, out: $stdout, allowed: ALLOWED_SKIPS)
      @suites = suites
      @strict = strict
      @out = out
      @allowed = allowed
      @runs = []
    end

    def run
      @suites.each { |suite| run_suite(suite) }
      report
      success?
    end

    def success?
      runs.none?(&:failed?) && (!@strict || unexpected_skips.empty?)
    end

    def unexpected_skips
      named = runs.flat_map { |run| run.skips.reject { |skip| @allowed.key?(skip.test) }.map { |skip| [run, skip] } }
      unnamed = runs.select { |run| run.unnamed_skips.positive? }.map do |run|
        [run, Skip.new(test: "#{run.unnamed_skips} unnamed skip(s)", location: run.label, message: "")]
      end
      named + unnamed
    end

    private

    def run_suite(suite)
      @out.puts "== #{suite.name} (#{suite.dir})"
      if suite.rake
        execute(suite, "#{suite.dir}: rake test", %w[bundle exec rake test])
      else
        suite.files.each { |file| execute(suite, File.join(suite.dir, file).delete_prefix("./"), test_command(suite, file)) }
      end
    end

    def test_command(suite, file)
      command = [RbConfig.ruby]
      command << "-rbundler/setup" if suite.bundled?
      command.push("-Ilib", "-Itest") if suite.gem?
      command.push(file, "--show-skips")
    end

    def execute(suite, label, command)
      env = { "TESTOPTS" => "--show-skips" }
      env["BUNDLE_GEMFILE"] = suite.gemfile if suite.bundled?
      output = +""
      status = nil
      Open3.popen2e(env, *command, chdir: suite.root) do |stdin, io, wait|
        stdin.close
        io.each_line do |line|
          @out.print line
          output << line
        end
        status = wait.value
      end
      run = Run.new(label, status, output)
      @runs << run
      @out.puts "-- #{label}: #{verdict(run)}"
    end

    def verdict(run)
      return "FAILED (exit #{run.status.exitstatus.inspect}, no minitest summary)" if run.summary.nil?

      runs, assertions, failures, errors, skips = run.summary
      text = "#{runs} runs, #{assertions} assertions, #{failures} failures, #{errors} errors, #{skips} skips"
      run.failed? ? "FAILED: #{text}" : text
    end

    def report
      failed = runs.select(&:failed?)
      skips = runs.flat_map { |run| run.skips.map { |skip| [run, skip] } }
      unexpected = unexpected_skips

      @out.puts
      @out.puts "== #{runs.length} processes, #{runs.sum(&:runs)} runs, #{failed.length} failed, #{skips.length + runs.sum(&:unnamed_skips)} skips"
      failed.each { |run| @out.puts "FAILED  #{run.label}" }
      skips.each do |run, skip|
        tag = @allowed.key?(skip.test) ? "allowed" : "skipped"
        @out.puts "#{tag.ljust(7)} #{skip.test} (#{run.label}): #{skip.message}"
        @out.puts "        allowed because: #{@allowed[skip.test]}" if tag == "allowed"
      end
      runs.select { |run| run.unnamed_skips.positive? }.each do |run|
        @out.puts "skipped #{run.unnamed_skips} test(s) in #{run.label} that --show-skips did not name"
      end
      return unless @strict && unexpected.any?

      @out.puts
      @out.puts "#{unexpected.length} unexpected skip(s). A cross-check stopped running: give CI what it needs, " \
                "or add the test to ALLOWED_SKIPS in tools/run_ruby_tests.rb with the reason."
    end
  end

  module_function

  def suites_named(names)
    return SUITES if names.empty?

    names.map do |name|
      SUITES.find { |suite| suite.name == name } || abort("Unknown suite #{name}. Suites: #{SUITES.map(&:name).join(', ')}")
    end
  end

  def main(argv)
    args = argv.dup
    strict = !args.delete("--strict").nil?
    if args.delete("--list")
      suites_named(args).each do |suite|
        puts "#{suite.name} (#{suite.dir}#{', rake test' if suite.rake}#{', Gemfile' if suite.bundled?})"
        suite.files.each { |file| puts "  #{file}" }
      end
      return 0
    end

    Runner.new(suites_named(args), strict: strict).run ? 0 : 1
  end
end

exit RufletRubyTests.main(ARGV) if $PROGRAM_NAME == __FILE__
