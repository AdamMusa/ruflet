# frozen_string_literal: true

require "minitest/autorun"
require "yaml"
require_relative "run_ruby_tests"

# CI used to run only three packages' tests and tools/mruby_patches_test.rb.
# ruflet_rails, ruflet_record, ruby_runtime and the other tools tests never ran,
# and a change under tools/ started no workflow at all, so fixes merged with
# their tests unrun. This pins the contract:
# - every Ruby test file in the repository belongs to a suite in
#   tools/run_ruby_tests.rb;
# - .github/workflows/ruby-tests.yml runs every suite with --strict;
# - a change to any file in a suite's folder (its lib/, Gemfile, Gemfile.lock
#   and tests), or to anything under tools/, triggers it;
# - the engine it checks ruflet_core against is pinned to a commit.
class RubyTestsWorkflowTest < Minitest::Test
  ROOT = RufletRubyTests::ROOT
  WORKFLOW = File.join(ROOT, ".github/workflows/ruby-tests.yml")

  # Test files no suite runs, and why.
  NOT_RUN = {
    "tools/embedded_vm_harness/tests/*_test.rb" => "run inside a host mruby VM build (tools/embedded_vm_harness)"
  }.freeze

  def test_every_ruby_test_file_belongs_to_a_suite
    covered = RufletRubyTests::SUITES.flat_map do |suite|
      suite.files.map { |file| File.join(suite.dir, file).delete_prefix("./") }
    end
    test_files = Dir.glob(["packages/*/test/**/*_test.rb", "ruby_runtime/test/**/*_test.rb", "tools/**/*_test.rb"], base: ROOT)
    test_files.reject! { |file| NOT_RUN.keys.any? { |pattern| File.fnmatch?(pattern, file, File::FNM_PATHNAME) } }

    assert_empty test_files.sort - covered, "test files no suite in tools/run_ruby_tests.rb runs"
  end

  def test_the_workflow_runs_every_suite_strictly
    strict = invocations.select { |args| args.include?("--strict") }.flat_map { |args| args - ["--strict"] }
    loose = invocations.reject { |args| args.include?("--strict") }

    assert_empty loose, "every run of tools/run_ruby_tests.rb in ruby-tests.yml passes --strict"
    assert_equal RufletRubyTests::SUITES.map(&:name).sort, strict.sort,
                 "ruby-tests.yml runs each suite exactly once"
  end

  def test_a_change_to_any_suite_or_to_tools_triggers_the_workflow
    watched = RufletRubyTests::SUITES.flat_map do |suite|
      suite.files.map { |file| File.join(suite.dir, file).delete_prefix("./") }
    end
    # Everything else in each suite's folder: the code under test (lib/), the
    # Gemfile and Gemfile.lock it runs under, and what its tests read.
    RufletRubyTests::SUITES.reject { |suite| suite.dir == "." }.each do |suite|
      watched += suite_files(suite.dir)
      watched += %w[Gemfile Gemfile.lock].map { |name| File.join(suite.dir, name) } if suite.bundled?
    end
    # What the suites load from outside their own folders.
    watched += suite_files("tools")
    watched += %w[.ruby-version .github/workflows/ruby-tests.yml]
    watched.uniq!

    assert_operator watched.grep(%r{\Apackages/[^/]+/lib/}).length, :>, 0, "the package suites have lib/ files"
    %w[pull_request push].each do |event|
      paths = triggers.fetch(event).fetch("paths")
      unmatched = watched.reject { |file| triggered?(paths, file) }

      assert_empty unmatched.first(20), "#{event} paths in ruby-tests.yml miss #{unmatched.length} file(s), such as these"
    end
  end

  # dsl_presented_controls_test compares ruflet_core with this engine checkout.
  # A moving ref would let an engine merge fail every later ruflet run.
  def test_the_engine_checkout_is_pinned_to_a_commit
    checkouts = workflow.fetch("jobs").values.flat_map { |job| job.fetch("steps") }.select do |step|
      step["uses"].to_s.start_with?("actions/checkout@") && step.dig("with", "repository") == "AdamMusa/ruflet-engine"
    end

    refute_empty checkouts, "ruby-tests.yml checks out ruflet-engine"
    checkouts.each { |step| assert_match(/\A\h{40}\z/, step.dig("with", "ref").to_s, "ruflet-engine checkout ref") }
  end

  def test_package_suites_install_their_gemfiles_before_running
    installed = scripts.flat_map do |script|
      script.scan(/^for package in ([^;\n]+); do\n[^\n]*bundle install/).flat_map { |(names)| names.split }
    end
    expected = RufletRubyTests::SUITES.select(&:bundled?).map { |suite| File.basename(suite.dir) }

    assert_equal expected.sort, installed.sort, "ruby-tests.yml runs bundle install in each package with a Gemfile"
  end

  private

  def workflow
    @workflow ||= YAML.safe_load(File.read(WORKFLOW))
  end

  # Every file under +dir+ (relative to ROOT), as a path relative to ROOT.
  def suite_files(dir)
    Dir.glob("#{dir}/**/*", base: ROOT).select { |path| File.file?(File.join(ROOT, path)) }
  end

  # YAML 1.1 reads a bare `on:` key as true.
  def triggers
    workflow.fetch("on") { workflow.fetch(true) }
  end

  def scripts
    workflow.fetch("jobs").values.flat_map { |job| job.fetch("steps").filter_map { |step| step["run"] } }
  end

  # The arguments of each `ruby tools/run_ruby_tests.rb ...` in a run step.
  def invocations
    scripts.flat_map do |script|
      script.scan(%r{ruby tools/run_ruby_tests\.rb([^\n]*)}).map { |(args)| args.split }
    end
  end

  # GitHub's paths filter: patterns apply in order, and a later !pattern
  # excludes what an earlier one matched.
  def triggered?(paths, file)
    paths.reduce(false) do |matched, pattern|
      if pattern.start_with?("!")
        matched && !github_glob?(pattern.delete_prefix("!"), file)
      else
        matched || github_glob?(pattern, file)
      end
    end
  end

  # ** matches across directories, * within one.
  def github_glob?(pattern, path)
    regexp = Regexp.escape(pattern).gsub("\\*\\*", "\u0000").gsub("\\*", "[^/]*").gsub("\u0000", ".*")
    path.match?(/\A#{regexp}\z/)
  end
end
