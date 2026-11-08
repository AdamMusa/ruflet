# frozen_string_literal: true

# One `ruflet` invocation inside a sandbox, with every process boundary
# replaced by a recorder. Spawned by lib/harness.rb as
#
#   ruby -I<stub_lib> -I<installed gem lib>... cli_child.rb <spec.json>
#
# in a clean environment, with the project as the working directory. Nothing
# here touches library code: the CLI runs unmodified and only sees fake
# executables, a fake network and a fixed clock.
#
# Tools are emulated, never executed:
#   flutter  pub get writes .dart_tool/package_config.json (the CLI verifies it);
#            build writes a placeholder output (the CLI exports it); the rest succeed.
#   dart, pod, mrbc, codesign, bundle, open: succeed (mrbc writes a placeholder .mrb).
#   git      ls-remote / rev-parse answer a fixed commit; clone checks out the
#            frozen fixture template.
# Only /usr/libexec/PlistBuddy runs for real: it rewrites Info.plist and its
# output is what users get. Any other command is recorded and fails.

Encoding.default_external = Encoding::UTF_8

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "pathname"
require "rbconfig"
require "socket"
require "stringio"
require "uri"
require "yaml"

module CompatChild
  SPEC = JSON.parse(File.read(ARGV.fetch(0)))
  OUTPUT = []
  COMMANDS = []
  STUB_WRITES = []
  NETWORK = []
  FAKE_COMMIT = SPEC.fetch("fake_commit")
  # Only host tool locations the CLI probes; Ruby's own install is never masked.
  HOST_PROBE_PREFIXES = %w[/opt/homebrew/bin/ /usr/local/bin/ /Applications/].freeze
  HOST_EXECUTABLES = SPEC.fetch("host_executables")
  PASSTHROUGH = %w[/usr/libexec/PlistBuddy].freeze

  class Stream < StringIO
    def initialize(tag)
      super()
      @tag = tag
    end

    def write(*parts)
      text = parts.join
      OUTPUT << [@tag, text]
      super
    end

    def tty? = false
    def isatty = false
  end

  FakeStatus = Struct.new(:exitstatus) do
    def success? = exitstatus.zero?
    def to_i = exitstatus << 8
    def pid = 0
  end

  REAL_SYSTEM = Kernel.instance_method(:system)
  REAL_SPAWN = Process.method(:spawn)

  class << self
    def record(via, env, argv, options)
      entry = { "via" => via, "argv" => argv.map(&:to_s) }
      entry["env"] = env.to_h { |key, value| [key.to_s, value.nil? ? nil : value.to_s] } unless env.nil? || env.empty?
      chdir = options[:chdir]
      entry["chdir"] = File.expand_path(chdir.to_s) if chdir
      extra = options.keys.map(&:to_s).reject { |key| key == "chdir" }.sort
      entry["options"] = extra unless extra.empty?
      COMMANDS << entry
      entry
    end

    def split_command(args, kwargs)
      args = args.dup
      env = args.first.is_a?(Hash) ? args.shift : nil
      options = kwargs.dup
      options.merge!(args.pop) if args.last.is_a?(Hash)
      argv = args.flat_map { |arg| arg.is_a?(Array) ? [arg.first] : [arg] }
      argv = argv.first.to_s.split if argv.length == 1 && argv.first.to_s.include?(" ") && !File.exist?(argv.first.to_s)
      [env, argv, options]
    end

    # Sets $? the way a finished child would, so `$?.exitstatus` reads right.
    def set_last_status(code)
      if code.zero?
        REAL_SYSTEM.bind_call(Kernel, "/usr/bin/true")
      else
        REAL_SYSTEM.bind_call(Kernel, "/bin/sh", "-c", "exit #{code}")
      end
    end

    def run_tool(env, argv, options)
      program = argv.first.to_s
      name = File.basename(program)
      cwd = options[:chdir] ? File.expand_path(options[:chdir].to_s) : Dir.pwd
      args = argv.drop(1).map(&:to_s)

      if program == RbConfig.ruby && args[0] == "-S" && args[1] == "bundle"
        return tool_result(true)
      end

      case name
      when "flutter" then flutter(args, cwd)
      when "dart" then dart(args, cwd)
      when "pod" then tool_result(args.first == "install")
      when "git" then git(args, cwd)
      when "mrbc" then mrbc(args, cwd)
      when "codesign", "open", "xdg-open" then tool_result(true)
      else
        tool_result(false, stderr: "compat harness: no emulation for #{program}\n")
      end
    end

    def tool_result(ok, stdout: "", stderr: "")
      { ok: ok, stdout: stdout, stderr: stderr }
    end

    # --- flutter ---------------------------------------------------------------

    def flutter(args, cwd)
      case args.first
      when "pub"
        return pub_get(cwd) if args[1] == "get"
      when "build"
        return flutter_build(args.drop(1), cwd)
      when "--version"
        if args.include?("--machine")
          return tool_result(true, stdout: JSON.generate(
            "frameworkVersion" => "3.41.2", "channel" => "stable", "dartSdkVersion" => "3.11.0"
          ))
        end
        return tool_result(true, stdout: "Flutter 3.41.2 • channel stable\n")
      end
      tool_result(true)
    end

    def pub_get(cwd)
      pubspec = File.join(cwd, "pubspec.yaml")
      return tool_result(false, stderr: "compat flutter: no pubspec.yaml\n") unless File.file?(pubspec)

      packages = {}
      queue = [[pubspec, cwd]]
      until queue.empty?
        manifest_path, root = queue.shift
        manifest = YAML.safe_load(File.read(manifest_path), aliases: true) || {}
        (manifest["dependencies"] || {}).each do |name, dependency|
          next unless dependency.is_a?(Hash) && dependency["path"]
          next if packages.key?(name)

          local = File.expand_path(dependency["path"].to_s, root)
          unless File.file?(File.join(local, "pubspec.yaml"))
            return tool_result(false, stderr: "compat flutter: path dependency #{name} not found at #{local}\n")
          end

          packages[name] = local
          queue << [File.join(local, "pubspec.yaml"), local]
        end
      end

      dart_tool = File.join(cwd, ".dart_tool")
      config = {
        "configVersion" => 2,
        "packages" => packages.sort.map do |name, root|
          {
            "name" => name,
            "rootUri" => Pathname.new(root).relative_path_from(Pathname.new(dart_tool)).to_s,
            "packageUri" => "lib/"
          }
        end,
        "generator" => "ruflet-compat-stub"
      }
      stub_write(File.join(dart_tool, "package_config.json"), JSON.pretty_generate(config))
      tool_result(true)
    end

    def flutter_build(args, cwd)
      target = args.first
      mode = args.include?("--debug") ? "debug" : "release"
      body = "ruflet compat placeholder: flutter build #{target}\n"
      outputs = case target
      when "apk" then ["build/app/outputs/flutter-apk/app-#{mode}.apk"]
      when "appbundle" then ["build/app/outputs/bundle/#{mode}/app-#{mode}.aab"]
      when "ios"
        sdk = args.include?("--simulator") ? "iphonesimulator" : "iphoneos"
        ["build/ios/#{sdk}/Runner.app/Info.plist"]
      when "ipa" then ["build/ios/archive/Runner.xcarchive/Info.plist", "build/ios/ipa/Runner.ipa"]
      when "web" then ["build/web/index.html", "build/web/main.dart.js", "build/web/flutter_bootstrap.js"]
      when "macos" then ["build/macos/Build/Products/Release/Runner.app/Contents/MacOS/Runner"]
      when "windows" then ["build/windows/x64/runner/Release/runner.exe"]
      when "linux" then ["build/linux/x64/release/bundle/runner"]
      else []
      end
      outputs.each do |relative|
        path = File.join(cwd, relative)
        stub_write(path, body)
        File.chmod(0o755, path) if relative.include?("/MacOS/") || relative.end_with?("/bundle/runner")
      end
      tool_result(true)
    end

    # The icon and splash generators: write the Android resources the CLI then
    # verifies, so goldens show the normal (generated) path. Everything else
    # they would produce is left out; their argv is what the goldens pin.
    def dart(args, cwd)
      res = File.join(cwd, "android", "app", "src", "main", "res")
      return tool_result(true) unless args.first == "run" && File.directory?(res)

      case args[1]
      when "flutter_native_splash:create"
        stub_write(File.join(res, "drawable", "launch_background.xml"), "<!-- compat: splash -->\n")
        stub_write(File.join(res, "values-v31", "styles.xml"), "<!-- compat: windowSplashScreenBackground -->\n")
      when "flutter_launcher_icons"
        stub_write(File.join(res, "mipmap-anydpi-v26", "launcher_icon.xml"), "<!-- compat: adaptive icon -->\n")
      end
      tool_result(true)
    end

    # --- git -------------------------------------------------------------------

    def git(args, _cwd)
      args = args.dup
      repo = nil
      if args.first == "-C"
        args.shift
        repo = File.expand_path(args.shift.to_s)
      end
      case args.first
      when "ls-remote"
        tool_result(true, stdout: "#{FAKE_COMMIT}\trefs/heads/main\n")
      when "clone"
        destination = File.expand_path(args.last.to_s)
        source = File.join(destination, "templates", "ruflet_flutter_template")
        FileUtils.mkdir_p(File.dirname(source))
        FileUtils.cp_r(SPEC.fetch("template_source"), source)
        FileUtils.mkdir_p(File.join(destination, ".git"))
        tool_result(true)
      when "sparse-checkout"
        tool_result(true)
      when "rev-parse"
        if repo && (File.directory?(File.join(repo, ".git")) || repo == SPEC["explicit_template_checkout"])
          tool_result(true, stdout: "#{FAKE_COMMIT}\n")
        else
          tool_result(false, stderr: "fatal: not a git repository (or any of the parent directories): .git\n")
        end
      else
        tool_result(false, stderr: "compat harness: no emulation for git #{args.first}\n")
      end
    end

    def mrbc(args, cwd)
      output = args[args.index("-o") + 1]
      source = args.last
      relative = Pathname.new(File.expand_path(source, cwd)).relative_path_from(Pathname.new(cwd)).to_s
      digest = Digest::SHA256.file(File.expand_path(source, cwd)).hexdigest
      File.binwrite(File.expand_path(output, cwd), "RITE compat placeholder for #{relative} sha256=#{digest}\n")
      tool_result(true)
    end

    def stub_write(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      STUB_WRITES << File.expand_path(path)
    end

    # --- interception entry points ---------------------------------------------

    def system_call(args, kwargs)
      env, argv, options = split_command(args, kwargs)
      entry = record("system", env, argv, options)
      if PASSTHROUGH.include?(argv.first.to_s)
        ok = REAL_SYSTEM.bind_call(Kernel, *argv, out: File::NULL, err: File::NULL)
        entry["result"] = ok ? 0 : 1
        return ok
      end
      result = run_tool(env, argv, options)
      $stdout.write(result[:stdout]) unless result[:stdout].empty? || options.key?(:out)
      $stderr.write(result[:stderr]) unless result[:stderr].empty? || options.key?(:err)
      entry["result"] = result[:ok] ? 0 : 1
      set_last_status(result[:ok] ? 0 : 1)
      result[:ok]
    end

    def capture(via, args, kwargs)
      env, argv, options = split_command(args, kwargs)
      entry = record(via, env, argv, options)
      result = run_tool(env, argv, options)
      entry["result"] = result[:ok] ? 0 : 1
      [result[:stdout], result[:stderr], FakeStatus.new(result[:ok] ? 0 : 1)]
    end

    # Long-running children (the app backend, browsers, desktop clients) are
    # recorded, then stood in for by a real process that exits at once, so the
    # CLI's own wait/kill/detach logic runs unchanged.
    def spawn_call(args, kwargs)
      env, argv, options = split_command(args, kwargs)
      record("spawn", env, argv, options)
      passed = options.select { |key, _| %i[pgroup].include?(key) }
      REAL_SPAWN.call("/usr/bin/true", in: File::NULL, out: File::NULL, err: File::NULL, **passed)
    end

    def host_probe(path)
      value = path.respond_to?(:to_path) ? path.to_path : path
      return nil unless value.is_a?(String)

      expanded = File.expand_path(value)
      return nil unless HOST_PROBE_PREFIXES.any? { |prefix| expanded.start_with?(prefix) }

      HOST_EXECUTABLES.include?(expanded)
    end

    def output_events
      merged = []
      OUTPUT.each do |stream, text|
        if merged.last && merged.last[0] == stream
          merged.last[1] << text
        else
          merged << [stream, text.dup]
        end
      end
      merged
    end
  end
end

# --- process boundary --------------------------------------------------------

module Kernel
  private

  def system(*args, **kwargs) = CompatChild.system_call(args, kwargs)
  def spawn(*args, **kwargs) = CompatChild.spawn_call(args, kwargs)

  def `(command)
    CompatChild.record("backtick", nil, [command], {})
    ""
  end

  def exec(*args, **kwargs)
    CompatChild.record("exec", nil, args.flatten.map(&:to_s), kwargs)
    raise NotImplementedError, "compat harness: exec is not emulated"
  end
end

class << Kernel
  def system(*args, **kwargs) = CompatChild.system_call(args, kwargs)
  def spawn(*args, **kwargs) = CompatChild.spawn_call(args, kwargs)
end

module Process
  class << self
    def spawn(*args, **kwargs) = CompatChild.spawn_call(args, kwargs)
  end
end

class IO
  class << self
    def popen(*args, **kwargs)
      CompatChild.record("popen", nil, args.flatten.map(&:to_s), kwargs)
      raise NotImplementedError, "compat harness: IO.popen is not emulated"
    end
  end
end

module Open3
  class << self
    def capture3(*args, **kwargs) = CompatChild.capture("capture3", args, kwargs)

    def capture2e(*args, **kwargs)
      stdout, stderr, status = CompatChild.capture("capture2e", args, kwargs)
      [stdout + stderr, status]
    end

    def capture2(*args, **kwargs)
      stdout, _stderr, status = CompatChild.capture("capture2", args, kwargs)
      [stdout, status]
    end

    %i[popen3 popen2 popen2e pipeline pipeline_r pipeline_w pipeline_rw pipeline_start].each do |name|
      define_method(name) do |*args, **kwargs, &_block|
        CompatChild.record(name.to_s, nil, args.flatten.map(&:to_s), kwargs)
        raise NotImplementedError, "compat harness: Open3.#{name} is not emulated"
      end
    end
  end
end

# The host this golden describes: an Apple-silicon Mac with Homebrew CocoaPods
# and no Chrome. Probes of other host paths answer from that profile.
[File.singleton_class].each do |klass|
  klass.prepend(Module.new do
    %i[executable? file? exist?].each do |probe|
      define_method(probe) do |path|
        answer = CompatChild.host_probe(path)
        answer.nil? ? super(path) : answer
      end
    end

    def directory?(path)
      answer = CompatChild.host_probe(path)
      answer.nil? ? super(path) : false
    end
  end)
end
Dir.singleton_class.prepend(Module.new do
  def exist?(path)
    answer = CompatChild.host_probe(path)
    answer.nil? ? super(path) : false
  end
end)
RbConfig::CONFIG["host_os"] = "darwin"
RbConfig::CONFIG["host_cpu"] = "arm64"

# A fixed clock: copyright years, manifest timestamps and update checks.
FROZEN_TIME = Time.at(CompatChild::SPEC.fetch("frozen_epoch")).utc
Time.singleton_class.prepend(Module.new do
  def now(**kwargs)
    kwargs.empty? ? FROZEN_TIME.getlocal : FROZEN_TIME.getlocal(kwargs[:in] || "+00:00")
  end
end)

# No real network. Local server probes succeed (the "server" is up); every
# HTTP request is recorded and answered 503.
class CompatFakeSocket
  def write(data) = data.to_s.bytesize
  def close = nil
  def closed? = true
end

TCPServer.singleton_class.prepend(Module.new do
  def new(*_args, **_kwargs) = CompatFakeSocket.new
  def open(*_args, **_kwargs) = CompatFakeSocket.new
end)
TCPSocket.singleton_class.prepend(Module.new do
  def new(host = nil, *_args, **_kwargs)
    raise Errno::ECONNREFUSED, "compat harness: #{host}" unless %w[127.0.0.1 localhost ::1].include?(host.to_s)

    CompatFakeSocket.new
  end

  def open(*args, **kwargs) = new(*args, **kwargs)
end)
Socket.singleton_class.prepend(Module.new do
  def ip_address_list
    [Addrinfo.ip("127.0.0.1"), Addrinfo.ip("192.168.1.23")]
  end

  def tcp(host, port, *_args, **_kwargs)
    raise Errno::ECONNREFUSED, "compat harness: #{host}:#{port}"
  end
end)

class CompatFakeHTTP
  def initialize(address, port)
    @address = address
    @port = port
  end

  def request(req, _body = nil)
    CompatChild::NETWORK << "#{req.method} #{req.uri || "https://#{@address}:#{@port}#{req.path}"}"
    response = Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")
    response.instance_variable_set(:@body, "")
    response.instance_variable_set(:@read, true)
    yield response if block_given?
    response
  end
end

Net::HTTP.prepend(Module.new do
  private

  def connect
    raise SocketError, "compat harness: network access is disabled (#{address}:#{port})"
  end
end)
Net::HTTP.singleton_class.prepend(Module.new do
  def start(address, *args, **_kwargs)
    port = args.first
    http = CompatFakeHTTP.new(address, port)
    return http unless block_given?

    yield http
  end
end)

# Ruby's own warnings ("file:line: warning: ...") differ between Ruby versions
# and are not CLI behavior; Kernel#warn output from the CLI passes through.
module Warning
  def warn(message, category: nil, **kwargs)
    return if message.to_s.match?(/\A[^\n]*:\d+: warning: /)

    super
  end
end

# --- run ------------------------------------------------------------------------

$stdout = CompatChild::Stream.new("out")
$stderr = CompatChild::Stream.new("err")

exit_code = begin
  if CompatChild::SPEC["mode"] == "rake"
    require_relative "rails_stub"
    CompatRails.boot(CompatChild::SPEC.fetch("project"))
    CompatRails.invoke_rake(CompatChild::SPEC.fetch("argv").first)
  else
    # The installed executable itself, exactly as `ruflet ...` runs it.
    ARGV.replace(CompatChild::SPEC.fetch("argv"))
    load CompatChild::SPEC.fetch("bin")
    0
  end
rescue SystemExit => e
  e.status
rescue Exception => e # rubocop:disable Lint/RescueException
  # What `ruflet` does with an uncaught exception: report it and exit 1. The
  # backtrace is left out on purpose; it names internal lines, not behavior.
  $stderr.write("<uncaught> #{e.class}: #{e.message}\n")
  1
end

File.write(
  CompatChild::SPEC.fetch("result_path"),
  JSON.pretty_generate(
    "exit" => exit_code,
    "output" => CompatChild.output_events,
    "commands" => CompatChild::COMMANDS,
    "network" => CompatChild::NETWORK,
    "stub_writes" => CompatChild::STUB_WRITES.uniq
  )
)
exit!(0)
