# frozen_string_literal: true

# Ruflet compatibility goldens: check (default), regenerate, or list them.
#
#   ruby packages/ruflet/test/compat/compat.rb                   # compare, exit 1 on any difference
#   ruby packages/ruflet/test/compat/compat.rb --regenerate      # rewrite goldens from this checkout
#   ruby packages/ruflet/test/compat/compat.rb --only build-apk  # restrict to ids containing a substring
#   ruby packages/ruflet/test/compat/compat.rb --list
#   ruby packages/ruflet/test/compat/compat.rb vendor-template --repo ../ruflet-template --ref <sha>
#   ruby packages/ruflet/test/compat/compat.rb docs-check --docs <ruflet_site>/app/content/docs
#
# The minitest entry point (test/compat_goldens_test.rb) runs the same check.

require "optparse"
require "etc"
require_relative "lib/harness"
require_relative "docs_coverage"

module RufletCompat
  module CLI
    module_function

    def main(argv)
      return vendor(argv.drop(1)) if argv.first == "vendor-template"
      return docs_check(argv.drop(1)) if argv.first == "docs-check"

      options = { mode: :check, only: nil, jobs: [Etc.nprocessors, 8].min }
      OptionParser.new do |parser|
        parser.on("--regenerate") { options[:mode] = :regenerate }
        parser.on("--check") { options[:mode] = :check }
        parser.on("--list") { options[:mode] = :list }
        parser.on("--only SUBSTRING") { |value| options[:only] = value }
        parser.on("--jobs N", Integer) { |value| options[:jobs] = value }
      end.parse!(argv)

      RufletCompat.validate_corpus!
      tasks = selected_tasks(options[:only])
      if options[:mode] == :list
        tasks.each { |task| puts task[:path].delete_prefix("#{GOLDEN_ROOT}/") }
        return 0
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Workspace.current
      results = run_parallel(tasks, options[:jobs])
      failures = 0
      results.each do |task, actual, error|
        if error
          failures += 1
          warn "ERROR #{relative(task[:path])}: #{error.class}: #{error.message}"
          next
        end

        if options[:mode] == :regenerate
          FileUtils.mkdir_p(File.dirname(task[:path]))
          File.write(task[:path], actual) unless File.file?(task[:path]) && read(task[:path]) == actual
        elsif !File.file?(task[:path])
          failures += 1
          warn "MISSING #{relative(task[:path])}"
        elsif read(task[:path]) != actual
          failures += 1
          warn "CHANGED #{relative(task[:path])}"
          warn TextDiff.unified(read(task[:path]), actual, old_label: "golden", new_label: "actual").lines.first(80).join
        end
      end

      stale = options[:only] ? [] : RufletCompat.stale_golden_paths
      if options[:mode] == :regenerate
        stale.each { |path| File.delete(path) }
        Dir.glob(File.join(GOLDEN_ROOT, "**", "*")).select { |dir| File.directory?(dir) && Dir.empty?(dir) }.each { |dir| Dir.rmdir(dir) }
      else
        stale.each do |path|
          failures += 1
          warn "STALE #{relative(path)} (no corpus entry produces it; run --regenerate)"
        end
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      verb = options[:mode] == :regenerate ? "regenerated" : "checked"
      puts "#{verb} #{tasks.length} goldens in #{elapsed.round(1)}s#{failures.zero? ? '' : ", #{failures} failing"}"
      failures.zero? ? 0 : 1
    end

    def selected_tasks(only)
      cli = Corpus::INVOCATIONS.map do |invocation|
        { kind: :cli, item: invocation, path: RufletCompat.cli_golden_path(invocation) }
      end
      pages = Corpus::PAGES.map { |page| { kind: :page, item: page, path: RufletCompat.page_golden_path(page) } }
      (cli + pages).select { |task| only.nil? || relative(task[:path]).include?(only) }
    end

    def render(task)
      task[:kind] == :cli ? RufletCompat.render_cli(task[:item]) : RufletCompat.render_page(task[:item])
    end

    def run_parallel(tasks, jobs)
      queue = Queue.new
      tasks.each_with_index { |task, index| queue << [task, index] }
      results = Array.new(tasks.length)
      Array.new([jobs, 1].max) do
        Thread.new do
          loop do
            task, index = queue.pop(true)
            begin
              results[index] = [task, render(task), nil]
            rescue StandardError => e
              results[index] = [task, nil, e]
            end
          rescue ThreadError
            break
          end
        end
      end.each(&:join)
      results
    end

    def read(path) = File.read(path, encoding: Encoding::UTF_8)

    def relative(path)
      path.delete_prefix("#{GOLDEN_ROOT}/")
    end

    # Lists every invocation a docs checkout shows (fenced shell blocks and
    # inline code) and fails if one is not in DocsCoverage::INVOCATIONS.
    def docs_check(argv)
      docs = nil
      OptionParser.new { |parser| parser.on("--docs DIR") { |value| docs = value } }.parse!(argv)
      abort "docs-check needs --docs <ruflet_site>/app/content/docs" unless docs && File.directory?(docs)

      found = documented_invocations(docs)
      missing = found.keys - DocsCoverage::INVOCATIONS.keys
      unlisted = DocsCoverage::INVOCATIONS.keys - found.keys
      missing.each { |form| warn "NOT COVERED #{form}  (#{found[form].first(3).join(', ')})" }
      unlisted.each { |form| warn "NO LONGER DOCUMENTED #{form}" }
      puts "#{found.length} documented invocations, #{found.length - missing.length} covered"
      missing.empty? && unlisted.empty? ? 0 : 1
    end

    def documented_invocations(docs)
      found = Hash.new { |hash, key| hash[key] = [] }
      Dir[File.join(docs, "*.md")].sort.each do |file|
        fence = nil
        File.readlines(file, encoding: Encoding::UTF_8).each_with_index do |line, index|
          if (opening = line.match(/\A\s*```(\w*)/))
            fence = fence ? nil : opening[1]
            next
          end
          candidates = if fence
                         %w[ruby erb yaml yml json dart html xml].include?(fence) ? [] : [line.strip]
                       else
                         line.scan(/`([^`]+)`/).map { |match| match.first.strip }
                       end
          candidates.each do |candidate|
            candidate.sub(/\A\$\s*/, "").sub(/\s+#.*\z/, "").split(/\s*(?:&&|;|\|\|)\s*/).each do |part|
              part = part.strip.sub(/\A(?:[A-Z_]+=\S+\s+)+/, "").sub(%r{\A(?:bundle exec |bin/)}, "")
              next unless part.match?(/\A(?:ruflet(?:\s|\z)|(?:rake|rails) ruflet:|rails (?:g|generate) ruflet)/)

              found[part.sub(/\Arails g /, "rails generate ").sub(/\Arails ruflet:/, "rake ruflet:")] <<
                "#{File.basename(file)}:#{index + 1}"
            end
          end
        end
      end
      found
    end

    def vendor(argv)
      require_relative "lib/vendor_template"
      options = { ref: "origin/main" }
      OptionParser.new do |parser|
        parser.on("--repo PATH") { |value| options[:repo] = value }
        parser.on("--ref REF") { |value| options[:ref] = value }
      end.parse!(argv)
      abort "vendor-template needs --repo <ruflet-template clone>" unless options[:repo]

      result = VendorTemplate.run(repo: File.expand_path(options[:repo]), ref: options[:ref],
                                  out_dir: File.join(FIXTURE_ROOT, "template"))
      puts "vendored ruflet-template #{result[:commit]} (#{result[:files]} files); now run --regenerate and review the diff"
      0
    end
  end
end

exit RufletCompat::CLI.main(ARGV.dup) if $PROGRAM_NAME == __FILE__
