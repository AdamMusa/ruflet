# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "tar"
require_relative "text_diff"
require_relative "../corpus"

module RufletCompat
  COMPAT_ROOT = File.expand_path("..", __dir__)
  PACKAGE_ROOT = File.expand_path("../..", COMPAT_ROOT)
  PACKAGES_ROOT = File.expand_path("..", PACKAGE_ROOT)
  GOLDEN_ROOT = File.join(COMPAT_ROOT, "goldens")
  FIXTURE_ROOT = File.join(COMPAT_ROOT, "fixtures")
  TEMPLATE_ARCHIVE = File.join(FIXTURE_ROOT, "template", "ruflet_flutter_template.tar")
  STUB_LIB = File.join(__dir__, "stub_lib")
  GENERATOR_STUB_LIB = File.join(__dir__, "generator_stub")
  CLI_CHILD = File.join(__dir__, "cli_child.rb")
  PAGE_CHILD = File.join(__dir__, "page_child.rb")

  # The installed gems a Ruflet developer has: the CLI and, for Rails apps and
  # page goldens, the runtime packages. Each is copied from this checkout using
  # its own gemspec's file list, so the code under test is exactly what ships.
  GEM_PACKAGES = %w[ruflet ruflet_core ruflet_server ruflet_rails].freeze
  # A fixed commit for the template the fake `git` serves.
  FAKE_COMMIT = "c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00"
  FROZEN_EPOCH = 1_767_268_800 # 2026-01-01T12:00:00Z
  HOST_EXECUTABLES = ["/opt/homebrew/bin/pod"].freeze
  SYSTEM_PATH = %w[/usr/bin /bin /usr/sbin /sbin].freeze
  CHILD_TIMEOUT = 180
  MOUNTS = ["<PROJECT>/build/client/", "<HOME>/.ruflet/templates/ruflet_flutter_template/"].freeze
  HEADER = <<~TEXT
    # Ruflet CLI compatibility golden (packages/ruflet/test/compat). Generated; do not edit.
    # Regenerate after an approved behavior change:
    #   ruby packages/ruflet/test/compat/compat.rb --regenerate
  TEXT

  FileState = Struct.new(:sha, :mode, :size, :path, :text, keyword_init: true)

  module_function

  def slug(argv)
    words = argv.map { |arg| arg.to_s.gsub(/[^A-Za-z0-9.-]+/, "_").gsub(/\A_+|_+\z/, "") }
    words.join("-").gsub(/-{3,}/, "--")
  end

  def invocation_id(invocation)
    return invocation["id"] if invocation["id"]

    id = slug(invocation["argv"])
    return "rake-#{id}" if invocation["rake"]
    return "generate-#{id}" if invocation["generator"]

    id
  end

  def invocation_mode(invocation)
    return "rake" if invocation["rake"]
    return "generator" if invocation["generator"]

    "cli"
  end

  def cli_golden_path(invocation)
    File.join(GOLDEN_ROOT, "cli", invocation["fixture"], "#{invocation_id(invocation)}.txt")
  end

  def page_golden_path(page)
    File.join(GOLDEN_ROOT, "page", "#{page['fixture']}.json")
  end

  def validate_corpus!
    seen = {}
    Corpus::INVOCATIONS.each do |invocation|
      raise "unknown fixture #{invocation['fixture']}" unless Corpus::FIXTURES.key?(invocation["fixture"])
      if (invocation["rake"] || invocation["generator"]) && !Corpus::FIXTURES[invocation["fixture"]]["rails"]
        raise "#{invocation_id(invocation)} needs a Rails fixture"
      end
      raise "unknown network #{invocation['network']}" unless [nil, "offline", "release"].include?(invocation["network"])

      # Case-insensitively: macOS file systems are.
      path = cli_golden_path(invocation).downcase
      raise "duplicate golden #{path}" if seen[path]

      seen[path] = true
    end
    true
  end

  def expected_golden_paths
    Corpus::INVOCATIONS.map { |inv| cli_golden_path(inv) } + Corpus::PAGES.map { |page| page_golden_path(page) }
  end

  def stale_golden_paths
    Dir.glob(File.join(GOLDEN_ROOT, "**", "*")).select { |path| File.file?(path) } - expected_golden_paths
  end

  def text?(data)
    !data.include?("\0".b) && data.dup.force_encoding(Encoding::UTF_8).valid_encoding?
  end

  def file_state(path, normalizer)
    stat = File.lstat(path)
    if stat.symlink?
      target = normalizer.call(File.readlink(path))
      return FileState.new(sha: Digest::SHA256.hexdigest("symlink:#{target}"), mode: "link", size: 0, path: path, text: "-> #{target}\n")
    end

    data = File.binread(path)
    text = text?(data) ? normalizer.call(data.dup.force_encoding(Encoding::UTF_8)) : nil
    digest = Digest::SHA256.hexdigest(text ? text.b : data)
    FileState.new(sha: digest, mode: (stat.mode & 0o111).zero? ? "644" : "755", size: (text || data).bytesize, path: path, text: text)
  end

  # Runs a child Ruby with a hard timeout. Returns [stdout, stderr, status].
  def run_process(env, command, chdir:)
    Open3.popen3(env, *command, chdir: chdir, unsetenv_others: true, pgroup: true) do |stdin, stdout, stderr, wait|
      stdin.close
      out_reader = Thread.new { stdout.read }
      err_reader = Thread.new { stderr.read }
      unless wait.join(CHILD_TIMEOUT)
        begin
          Process.kill("KILL", -wait.pid)
        rescue Errno::ESRCH
          nil
        end
        wait.join
        raise "compat child timed out after #{CHILD_TIMEOUT}s: #{command.join(' ')}"
      end
      [out_reader.value.force_encoding(Encoding::UTF_8), err_reader.value.force_encoding(Encoding::UTF_8), wait.value]
    end
  end

  # Everything shared by one test run: the frozen template, the simulated gem
  # installation and the fake Flutter SDK. Built once, in a temp directory.
  class Workspace
    attr_reader :dir, :template_dir, :template_index, :gem_home, :gem_libs, :gem_bin, :flutter_sdk, :fvm_bin, :ruflet_version

    @mutex = Mutex.new

    class << self
      def current
        @mutex.synchronize { @current ||= new }
      end
    end

    def initialize
      @dir = File.realpath(Dir.mktmpdir("ruflet-compat-"))
      if RufletCompat.keep_sandboxes?
        warn "ruflet compat workspace (kept): #{@dir}"
      else
        at_exit { FileUtils.rm_rf(@dir) }
      end
      @lock = Mutex.new
      @generated = {}
      @counter = 0
      extract_template
      install_gems
      write_flutter_sdk
      # Generated fixtures are built up front, before tests run in parallel.
      Corpus::FIXTURES.each_key { |name| generated(name) if %w[generated docs].include?(Corpus::FIXTURES[name]["kind"]) }
    end

    def next_id
      @lock.synchronize { @counter += 1 }
    end

    def extract_template
      root = File.join(@dir, "template")
      @template_index = {}
      File.open(TEMPLATE_ARCHIVE, "rb") { |io| Tar.read(io) }.each do |entry|
        path = File.join(root, entry.path)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, entry.data)
        File.chmod(entry.mode, path)
        relative = entry.path.delete_prefix("ruflet_flutter_template/")
        @template_index[relative] = {
          sha: Digest::SHA256.hexdigest(entry.data),
          mode: (entry.mode & 0o111).zero? ? "644" : "755",
          data: entry.data
        }
      end
      @template_dir = File.join(root, "ruflet_flutter_template")
    end

    def install_gems
      @gem_home = File.join(@dir, "gem_home")
      @gem_libs = {}
      GEM_PACKAGES.each do |name|
        source = File.join(PACKAGES_ROOT, name)
        script = <<~RUBY
          require "json"
          spec = Gem::Specification.load(ARGV.fetch(0))
          print JSON.generate("name" => spec.name, "version" => spec.version.to_s, "files" => spec.files,
                              "bindir" => spec.bindir, "executables" => spec.executables)
        RUBY
        out, err, status = Open3.capture3(RbConfig.ruby, "-e", script, "#{name}.gemspec", chdir: source)
        raise "could not read #{name}.gemspec: #{err}" unless status.success?

        spec = JSON.parse(out)
        root = File.join(@gem_home, "gems", "#{spec['name']}-#{spec['version']}")
        files = spec["files"] + spec["executables"].map { |exe| File.join(spec["bindir"], exe) }
        files.uniq.each do |relative|
          from = File.join(source, relative)
          next unless File.file?(from)

          to = File.join(root, relative)
          FileUtils.mkdir_p(File.dirname(to))
          FileUtils.cp(from, to, preserve: true)
        end
        @gem_libs[name] = File.join(root, "lib")
        @gem_bin = File.join(root, "bin", "ruflet") if name == "ruflet"
        @ruflet_version = spec["version"] if name == "ruflet"
      end
    end

    # `which flutter` must find something; these never run (the child
    # emulates them in-process) and fail loudly if they ever do. `fvm` is only
    # on PATH for entries with `host_fvm: true`.
    def write_flutter_sdk
      @flutter_sdk = File.join(@dir, "flutter")
      @fvm_bin = File.join(@dir, "fvm", "bin")
      [[File.join(@flutter_sdk, "bin"), "flutter"], [File.join(@flutter_sdk, "bin"), "dart"], [@fvm_bin, "fvm"]].each do |dir, tool|
        path = File.join(dir, tool)
        FileUtils.mkdir_p(dir)
        File.write(path, "#!/bin/sh\necho 'ruflet compat: #{tool} must be emulated, never executed' >&2\nexit 97\n")
        File.chmod(0o755, path)
      end
    end

    # A fixture project's starting files, materialized once per run.
    def fixture_source(name)
      fixture = Corpus::FIXTURES.fetch(name)
      case fixture["kind"]
      when "dir" then File.join(COMPAT_ROOT, fixture["path"])
      when "generated", "docs" then generated(name)
      end
    end

    def generated(name)
      return @generated[name] if @generated.key?(name)

      fixture = Corpus::FIXTURES.fetch(name)
      target = File.join(@dir, "generated", name)
      if fixture["kind"] == "generated"
        sandbox = Sandbox.new(self, "empty", "generate-#{name}")
        result = sandbox.run_step({ "argv" => fixture["argv"] })
        raise "could not generate #{name}: #{result.inspect}" unless result["exit"].zero?

        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(File.join(sandbox.project, fixture["argv"].last), target, preserve: true)
      else
        base = generated(fixture.fetch("base"))
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(base, target, preserve: true)
        FileUtils.cp(File.join(COMPAT_ROOT, fixture.fetch("snippet")), File.join(target, "main.rb"))
      end
      @generated[name] = target
    end
  end

  # One invocation's private world: project, HOME, TMPDIR, and optionally a
  # local ruby_runtime or a template checkout.
  class Sandbox
    attr_reader :workspace, :root, :project, :home, :tmp, :fixture

    def initialize(workspace, fixture, label)
      @workspace = workspace
      @fixture = fixture
      @root = File.join(workspace.dir, "runs", "#{format('%03d', workspace.next_id)}-#{label}")
      @home = File.join(@root, "home")
      @tmp = File.join(@root, "tmp")
      project_name = fixture == "empty" ? "projects" : fixture
      @project = File.join(@root, "proj", project_name)
      @specs = File.join(workspace.dir, "specs")
      [@home, @tmp, @specs, File.dirname(@project)].each { |dir| FileUtils.mkdir_p(dir) }
      source = fixture == "empty" ? nil : workspace.fixture_source(fixture)
      if source
        FileUtils.cp_r(source, @project, preserve: true)
      else
        FileUtils.mkdir_p(@project)
      end
      @steps = 0
    end

    def runtime_dir = File.join(@root, "ruby_runtime")
    def template_checkout = File.join(@root, "ruflet-template")
    def client_copy_dir = File.join(@root, "client")

    def prepare(invocation)
      (invocation["files"] || {}).each do |relative, content|
        path = File.join(@project, relative)
        if content.nil?
          FileUtils.rm_rf(path)
          next
        end
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        File.chmod(0o755, path) if content.start_with?("#!")
      end
      if invocation["runtime"]
        FileUtils.cp_r(File.join(FIXTURE_ROOT, "ruby_runtime"), runtime_dir, preserve: true)
      end
      if invocation["template"] == "explicit"
        target = File.join(template_checkout, "templates", "ruflet_flutter_template")
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp_r(workspace.template_dir, target, preserve: true)
      end
      # A Flutter client outside the project, for RUFLET_CLIENT_DIR.
      FileUtils.cp_r(workspace.template_dir, client_copy_dir, preserve: true) if invocation["client_copy"]
      seed_prebuilt_clients if invocation["seed"] == "prebuilt_clients"
    end

    # A prebuilt Explorer cache that is current at the frozen clock, so the
    # CLI launches it instead of checking GitHub.
    def seed_prebuilt_clients
      root = File.join(@home, ".ruflet", "client", workspace.ruflet_version, "macos")
      { "web/index.html" => "<!doctype html>\n", "web/main.dart.js" => "// compat\n",
        "web/flutter_bootstrap.js" => "// compat\n" }.each do |relative, content|
        FileUtils.mkdir_p(File.dirname(File.join(root, relative)))
        File.write(File.join(root, relative), content)
      end
      executable = File.join(root, "desktop", "Ruflet Explorer.app", "Contents", "MacOS", "Ruflet Explorer")
      FileUtils.mkdir_p(File.dirname(executable))
      File.write(executable, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, executable)
      checked = Time.at(FROZEN_EPOCH).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      manifest = {
        "schema" => 2, "ruflet_version" => workspace.ruflet_version, "platform" => "macos",
        "release_tag" => "v#{workspace.ruflet_version}", "release_revision" => "compat", "released_at" => checked,
        "checked_at" => checked, "installed_at" => checked,
        "targets" => [
          { "kind" => "web", "platform" => "macos", "asset_name" => "ruflet_explorer-web.tar.gz", "release_revision" => "compat" },
          { "kind" => "desktop", "platform" => "macos", "asset_name" => "ruflet_explorer-macos-universal.zip",
            "release_revision" => "compat" }
        ]
      }
      File.write(File.join(root, "manifest.json"), JSON.pretty_generate(manifest))
    end

    def env_for(invocation)
      tool_dirs = [File.join(workspace.flutter_sdk, "bin")]
      tool_dirs << workspace.fvm_bin if invocation["host_fvm"]
      env = {
        "PATH" => (tool_dirs + SYSTEM_PATH).join(File::PATH_SEPARATOR),
        "HOME" => @home,
        "TMPDIR" => @tmp,
        "TZ" => "UTC",
        "LANG" => "en_US.UTF-8",
        "LC_ALL" => "en_US.UTF-8",
        "GEM_HOME" => workspace.gem_home,
        "GEM_PATH" => workspace.gem_home
      }
      env["RUFLET_RUBY_RUNTIME_PATH"] = runtime_dir if invocation["runtime"]
      env["RUFLET_TEMPLATE_ROOT"] = template_checkout if invocation["template"] == "explicit"
      # Corpus env values may name the sandbox as <PROJECT> and <SANDBOX>.
      env.merge((invocation["env"] || {}).transform_values do |value|
        value.to_s.gsub("<PROJECT>", @project).gsub("<SANDBOX>", @root)
      end)
    end

    def run_step(invocation, argv: invocation["argv"])
      @steps += 1
      base = File.join(@specs, "#{File.basename(@root)}-#{@steps}")
      mode = RufletCompat.invocation_mode(invocation)
      libs = mode == "cli" ? [workspace.gem_libs.fetch("ruflet")] : GEM_PACKAGES.map { |name| workspace.gem_libs.fetch(name) }
      stubs = [STUB_LIB]
      stubs.unshift(GENERATOR_STUB_LIB) if mode == "generator" && !invocation["real_rails"]
      spec = {
        "mode" => mode,
        "network" => invocation["network"] || "offline",
        "argv" => argv,
        "bin" => workspace.gem_bin,
        "project" => @project,
        "result_path" => "#{base}.result.json",
        "template_source" => workspace.template_dir,
        "explicit_template_checkout" => invocation["template"] == "explicit" ? template_checkout : nil,
        "fake_commit" => FAKE_COMMIT,
        "flutter_sdk" => workspace.flutter_sdk,
        "frozen_epoch" => FROZEN_EPOCH,
        "host_executables" => HOST_EXECUTABLES
      }
      File.write("#{base}.json", JSON.generate(spec))
      command = [RbConfig.ruby, *(stubs + libs).flat_map { |lib| ["-I", lib] }, CLI_CHILD, "#{base}.json"]
      env = env_for(invocation)
      # The railties cross-check (compat_goldens_test.rb) loads the installed
      # rails gems as well as the sandboxed Ruflet gems.
      env["GEM_PATH"] = [workspace.gem_home, *Gem.path].uniq.join(File::PATH_SEPARATOR) if invocation["real_rails"]
      stdout, stderr, = RufletCompat.run_process(env, command, chdir: @project)
      unless File.file?(spec["result_path"])
        raise "compat child produced no result for #{argv.join(' ')}:\n#{stdout}\n#{stderr}"
      end

      result = JSON.parse(File.read(spec["result_path"], encoding: Encoding::UTF_8))
      result["process_stdout"] = stdout
      result["process_stderr"] = stderr
      result
    end

    def run_page(page)
      base = File.join(@specs, "#{File.basename(@root)}-page")
      spec = page.merge(
        "project" => @project,
        "result_path" => "#{base}.result.json",
        "rails_stub" => page["rails"] && page["fixture"] == "rails_app"
      )
      File.write("#{base}.json", JSON.generate(spec))
      libs = GEM_PACKAGES.map { |name| workspace.gem_libs.fetch(name) }
      command = [RbConfig.ruby, *libs.flat_map { |lib| ["-I", lib] }, PAGE_CHILD, "#{base}.json"]
      stdout, stderr, = RufletCompat.run_process(env_for({}), command, chdir: @project)
      raise "page child produced no result for #{page['fixture']}:\n#{stdout}\n#{stderr}" unless File.file?(spec["result_path"])

      JSON.parse(File.read(spec["result_path"], encoding: Encoding::UTF_8))
    end

    def replacements
      @replacements ||= begin
        pairs = {
          @project => "<PROJECT>",
          @home => "<HOME>",
          @tmp => "<TMP>",
          runtime_dir => "<SANDBOX>/ruby_runtime",
          template_checkout => "<SANDBOX>/ruflet-template",
          @root => "<SANDBOX>",
          workspace.template_dir => "<TEMPLATE>",
          workspace.flutter_sdk => "<FLUTTER_SDK>",
          workspace.fvm_bin => "<FVM_BIN>",
          workspace.gem_home => "<GEM_HOME>",
          workspace.dir => "<WORK>",
          COMPAT_ROOT => "<COMPAT>",
          PACKAGES_ROOT => "<PACKAGES>",
          RbConfig.ruby => "<RUBY>"
        }
        pairs[@project.gsub(/[^a-zA-Z0-9]+/, "-").delete_prefix("-")] = "<PROJECT_KEY>"
        pairs.sort_by { |path, _| -path.length }
      end
    end

    # Masks this machine and this run: sandbox paths, temp-dir suffixes and
    # the Ruflet version (so a release bump alone never changes a golden).
    def normalize(text, runtime_values: false)
      out = text.to_s.dup
      replacements.each { |path, label| out = out.gsub(path, label) }
      out = out.gsub(%r{(<TMP>/[A-Za-z_.-]+?)\d{8}-\d+-[0-9a-z]+}) { "#{Regexp.last_match(1)}XXXXXXXX" }
      out = out.gsub(/ruflet\d{8}-\d+-[0-9a-z]+\.yaml/, "ruflet<TEMPFILE>.yaml")
      out = out.gsub(/(?<![\d.])#{Regexp.escape(workspace.ruflet_version)}(?![\d.])/, "<RUFLET_VERSION>")
      if runtime_values
        out = out.gsub(/(?<![\d.])#{Regexp.escape(RUBY_VERSION)}(?![\d.])/, "<RUBY_VERSION>")
      end
      out
    end

    def snapshot
      states = {}
      normalizer = ->(text) { normalize(text) }
      Dir.glob(File.join(@root, "**", "*"), File::FNM_DOTMATCH).sort.each do |path|
        next if path.end_with?("/.", "/..")
        next if path == @tmp || path.start_with?("#{@tmp}/")
        next unless File.symlink?(path) || File.file?(path)

        states[display(path)] = RufletCompat.file_state(path, normalizer)
      end
      states
    end

    # A sandbox file as goldens name it. The Ruflet version is masked here as
    # in file contents: the prebuilt client cache lives under it.
    def display(path)
      shown = if path.start_with?("#{@project}/")
                "<PROJECT>#{path.delete_prefix(@project)}"
              elsif path.start_with?("#{@home}/")
                "<HOME>#{path.delete_prefix(@home)}"
              else
                "<SANDBOX>#{path.delete_prefix(@root)}"
              end
      shown.gsub(%r{/#{Regexp.escape(workspace.ruflet_version)}/}, "/<RUFLET_VERSION>/")
    end
  end

  # --- CLI goldens ---------------------------------------------------------------

  def keep_sandboxes? = !ENV["RUFLET_COMPAT_KEEP"].to_s.empty?

  def render_cli(invocation, workspace: Workspace.current)
    sandbox = Sandbox.new(workspace, invocation["fixture"], invocation_id(invocation))
    sandbox.prepare(invocation)
    (invocation["before"] || []).each do |argv|
      setup = sandbox.run_step(invocation.reject { |key, _| %w[rake generator].include?(key) }, argv: argv)
      raise "setup step `ruflet #{argv.join(' ')}` failed (exit #{setup['exit']})" unless setup["exit"].zero?
    end
    before = sandbox.snapshot
    result = sandbox.run_step(invocation)
    after = sandbox.snapshot
    stub_paths = result["stub_writes"].map { |path| sandbox.display(path) }
    stub_contents = result["stub_contents"].to_h do |path, text|
      [sandbox.display(path), { sha: Digest::SHA256.hexdigest(text.b), text: sandbox.normalize(text) }]
    end
    render_cli_golden(invocation, sandbox, result, before, after, stub_paths, stub_contents)
  ensure
    FileUtils.rm_rf(sandbox.root) if sandbox && !keep_sandboxes?
  end

  def render_cli_golden(invocation, sandbox, result, before, after, stub_paths, stub_contents = {})
    out = +HEADER
    out << "fixture: #{invocation['fixture']}\n"
    words = invocation["argv"].map { |word| display_word(word) }
    command = case invocation_mode(invocation)
              when "rake" then "rake #{words.join(' ')}"
              when "generator" then "rails generate #{words.join(' ')}"
              else "ruflet #{words.join(' ')}".rstrip
              end
    out << "command: #{command}\n"
    (sandbox.env_for(invocation).to_a - sandbox.env_for({}).to_a).sort.each do |key, value|
      out << "env: #{key}=#{sandbox.normalize(value)}\n"
    end
    (invocation["before"] || []).each { |argv| out << "before: ruflet #{argv.map { |word| display_word(word) }.join(' ')}\n" }
    out << "seed: #{invocation['seed']}\n" if invocation["seed"]
    out << "network: release fixture (lib/release_fixture.rb)\n" if invocation["network"] == "release"
    (invocation["files"] || {}).sort.each do |relative, content|
      out << (content.nil? ? "removed file: #{relative}\n" : "added file: #{relative}\n")
    end
    out << "exit: #{result['exit']}\n"

    out << "\n## commands (#{result['commands'].length})\n"
    result["commands"].each_with_index do |entry, index|
      out << render_command(entry, index + 1, sandbox)
    end

    unless result["network"].empty?
      out << "\n## network (#{result['network'].length})\n"
      result["network"].each { |line| out << "#{sandbox.normalize(line, runtime_values: true)}\n" }
    end

    out << "\n## output\n"
    result["output"].each do |stream, text|
      sandbox.normalize(text, runtime_values: true).each_line { |line| out << "#{stream}| #{line.chomp}\n" }
    end
    %w[process_stdout process_stderr].each do |key|
      next if result[key].to_s.empty?

      out << "\n## #{key.tr('_', ' ')} (outside the CLI)\n"
      sandbox.normalize(result[key], runtime_values: true).each_line { |line| out << "#{line.chomp}\n" }
    end

    out << render_files(before, after, stub_paths, sandbox.workspace, stub_contents)
    out
  end

  def render_command(entry, number, sandbox)
    text = +"#{number}. #{entry['via']}"
    text << " cwd=#{sandbox.normalize(entry['chdir'])}" if entry["chdir"]
    text << " exit=#{entry['result']}" if entry.key?("result")
    words = entry["argv"].map { |word| display_word(sandbox.normalize(word, runtime_values: true)) }
    text << "\n   #{words.join(' ')}\n"
    if entry["env"]
      pairs = entry["env"].sort.map do |key, value|
        value.nil? ? "#{key}=(unset)" : "#{key}=#{display_word(sandbox.normalize(value, runtime_values: true))}"
      end
      text << "   env: #{pairs.join(' ')}\n"
    end
    text << "   options: #{entry['options'].join(' ')}\n" if entry["options"]
    text
  end

  # Shell-like, but placeholders such as <HOME> stay readable.
  def display_word(word)
    word.match?(%r{\A[A-Za-z0-9_@%+=:,./<>\[\]-]+\z}) ? word : word.inspect
  end

  # Files a stub wrote (package_config.json, the generators' resources, build
  # outputs) are not CLI output and are only listed by name, unless the CLI
  # then changed or removed them: that is CLI behavior and is shown.
  def render_files(before, after, stub_paths, workspace, stub_contents = {})
    template = workspace.template_index
    listed = []
    identical = Hash.new(0)
    new_mounts = MOUNTS.select do |mount|
      before.keys.none? { |path| path.start_with?(mount) } && after.keys.any? { |path| path.start_with?(mount) }
    end

    (before.keys | after.keys).sort.each do |path|
      if stub_paths.include?(path)
        stub = stub_contents[path]
        final = after[path]
        if final.nil?
          listed << [:deleted_stub, path, nil]
        elsif stub && Digest::SHA256.hexdigest(File.binread(final.path)) != stub[:sha]
          listed << [:modified_stub, path, final, stub]
        end
        next
      end

      old = before[path]
      new = after[path]
      mount = MOUNTS.find { |prefix| path.start_with?(prefix) }
      relative = mount && path.delete_prefix(mount)
      base = mount && template[relative]
      if old.nil?
        if base && new.mode == base[:mode] && File.binread(new.path) == base[:data]
          identical[mount] += 1
          next
        end
        listed << [:added, path, new, base, relative]
      elsif new.nil?
        listed << [:deleted, path, old]
      elsif old.sha != new.sha || old.mode != new.mode
        listed << [:modified, path, new, old]
      end
    end

    out = +"\n## files\n"
    new_mounts.each do |mount|
      present = after.keys.select { |path| path.start_with?(mount) }.map { |path| path.delete_prefix(mount) }
      absent = template.keys.sort - present
      out << "#{mount} created from the template: #{identical[mount]} files identical, " \
             "#{absent.length} template files absent\n"
      collapse_paths(absent, template.keys).each { |line| out << "  absent: #{line}\n" }
    end
    (MOUNTS - new_mounts).each do |mount|
      out << "#{mount} #{identical[mount]} files added identical to the template\n" if identical[mount].positive?
    end
    out << "(no files changed)\n" if listed.empty? && new_mounts.empty?
    listed.each do |kind, path, state, other, _relative|
      case kind
      when :added
        origin = other ? "from template, edited" : "new"
        out << "A #{path}  #{describe(state)}  (#{origin})\n"
      when :deleted
        out << "D #{path}\n"
      when :deleted_stub
        out << "D #{path}  (removed after a stub wrote it)\n"
      when :modified_stub
        out << "M #{path}  stub output -> #{describe(state)}  (changed after a stub wrote it)\n"
      when :modified
        out << "M #{path}  #{describe(other)} -> #{describe(state)}\n"
      end
    end
    out << "\n## stub side effects (not CLI output)\n" unless stub_paths.empty?
    stub_paths.uniq.sort.each { |path| out << "  #{path}\n" }

    diffs = listed.filter_map { |entry| render_diff(*entry) }
    out << "\n## diffs\n" << diffs.join unless diffs.empty?
    out
  end

  # Lists whole directories once: "ruflet_packages/ruflet_ads/ (2 files)".
  def collapse_paths(paths, universe)
    chosen = paths.to_h { |path| [path, true] }
    by_dir = Hash.new { |hash, key| hash[key] = [] }
    universe.each do |path|
      parts = path.split("/")
      (1...parts.length).each { |depth| by_dir[parts[0, depth].join("/")] << path }
    end
    lines = []
    seen = {}
    paths.sort.each do |path|
      parts = path.split("/")
      top = (1...parts.length).map { |depth| parts[0, depth].join("/") }.find do |dir|
        by_dir[dir].all? { |member| chosen[member] }
      end
      if top
        next if seen[top]

        seen[top] = true
        lines << "#{top}/ (#{by_dir[top].length} files)"
      else
        lines << path
      end
    end
    lines
  end

  def describe(state)
    mode = state.mode == "644" ? "" : " mode=#{state.mode}"
    kind = state.text ? "" : " binary"
    "sha256:#{state.sha[0, 16]} #{state.size}b#{kind}#{mode}"
  end

  NEW_FILE_LINE_LIMIT = 400

  def render_diff(kind, path, state, other = nil, relative = nil)
    return nil if %i[deleted deleted_stub].include?(kind)
    return "Binary #{path}: sha256:#{state.sha[0, 16]}\n" unless state.text

    case kind
    when :added
      if other
        base = other[:data].dup.force_encoding(Encoding::UTF_8)
        return "Binary template #{relative} replaced by text #{path}\n" unless base.valid_encoding?

        TextDiff.unified(base, state.text, old_label: "<TEMPLATE>/#{relative}", new_label: path)
      else
        lines = state.text.lines
        shown = lines.first(NEW_FILE_LINE_LIMIT).join
        diff = TextDiff.unified("", shown, old_label: "/dev/null", new_label: path)
        diff << "+... (#{lines.length - NEW_FILE_LINE_LIMIT} more lines)\n" if lines.length > NEW_FILE_LINE_LIMIT
        diff
      end
    when :modified
      return "Binary #{path}: changed\n" unless other.text

      TextDiff.unified(other.text, state.text, old_label: "before:#{path}", new_label: path)
    when :modified_stub
      TextDiff.unified(other[:text], state.text, old_label: "stub:#{path}", new_label: path)
    end
  end

  # --- page goldens ------------------------------------------------------------

  def render_page(page, workspace: Workspace.current)
    sandbox = Sandbox.new(workspace, page["fixture"], "page-#{page['fixture']}")
    result = sandbox.run_page(page)
    normalized = deep_map(result) { |value| sandbox.normalize(value, runtime_values: true) }
    "#{JSON.pretty_generate(normalized)}\n"
  ensure
    FileUtils.rm_rf(sandbox.root) if sandbox && !keep_sandboxes?
  end

  def deep_map(value, &block)
    case value
    when Hash then value.transform_values { |item| deep_map(item, &block) }
    when Array then value.map { |item| deep_map(item, &block) }
    when String then yield(value)
    else value
    end
  end
end
