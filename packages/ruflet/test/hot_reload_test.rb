# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "rbconfig"
require "minitest/mock"
require "timeout"

CORE_LIB = File.expand_path("../../ruflet_core/lib", __dir__)
# The runner hooks Ruflet::Server#start; keep it on this checkout's server,
# not an installed ruflet_server gem.
SERVER_LIB = File.expand_path("../../ruflet_server/lib", __dir__)
$LOAD_PATH.unshift(CORE_LIB)
$LOAD_PATH.unshift(SERVER_LIB)
require "ruflet/hot_reload"

class RufletHotReloadTest < Minitest::Test
  class FakeServer
    attr_reader :app_block, :reload_count

    def initialize(&app_block)
      @app_block = app_block
      @reload_count = 0
      @queue = Queue.new
    end

    def start
      @queue.pop
    end

    def reload_app!
      @reload_count += 1
    end

    def shutdown
      @queue << :stop
    end
  end

  class RecorderPage
    attr_reader :added

    def initialize
      @added = []
    end

    def add(value)
      @added << value
    end

    # What a DSL app's block calls on the page before adding its roots.
    def set_view_props(_props); end

    def labels
      @added.map { |item| item.respond_to?(:props) ? item.props["value"] : item }
    end
  end

  def setup
    @dir = Dir.mktmpdir("ruflet-hot-reload-")
    @script = File.join(@dir, "main.rb")
    @logs = []
    # Several tests serve the app's own Ruflet::Server.
    @previous_banner = ENV["RUFLET_SUPPRESS_SERVER_BANNER"]
    ENV["RUFLET_SUPPRESS_SERVER_BANNER"] = "1"
  end

  def teardown
    stop_served_runner
    @thread&.join(2)
    @thread&.kill
    @runner&.stop
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
    @previous_banner.nil? ? ENV.delete("RUFLET_SUPPRESS_SERVER_BANNER") : ENV["RUFLET_SUPPRESS_SERVER_BANNER"] = @previous_banner
  end

  def test_captures_app_block_without_starting_a_real_server
    write_widgets("v1")
    write_main
    start_runner

    assert_instance_of FakeServer, @runner.server
    assert_equal ["v1"], render
  end

  def test_file_change_reloads_required_files_and_swaps_the_block
    write_widgets("v1")
    write_main
    start_runner

    write_widgets("v2")
    wait_until("first reload") { @runner.reload_count >= 1 }

    assert_equal 1, @runner.server.reload_count
    assert_equal ["v2"], render
  end

  def test_broken_script_keeps_previous_block_and_recovers
    write_widgets("v1")
    write_main
    start_runner

    File.write(File.join(@dir, "widgets.rb"), "def broken(\n")
    wait_until("reload failure log") { @logs.any? { |line| line.include?("reload failed") } }

    assert_equal 0, @runner.reload_count
    assert_equal ["v1"], render, "a broken reload must keep the last good UI block"

    write_widgets("v3")
    wait_until("recovery reload") { @runner.reload_count >= 1 }
    assert_equal ["v3"], render
  end

  def test_manual_reload_request_triggers_without_file_changes
    write_widgets("v1")
    write_main
    start_runner

    @runner.request_reload
    wait_until("forced reload") { @runner.reload_count >= 1 }
    assert_equal ["v1"], render
  end

  def test_reports_ready_on_the_cli_fd_once_reload_is_armed
    write_widgets("v1")
    write_main
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    # The limit only stops a runner that never reports from hanging the suite.
    assert IO.select([reader], nil, nil, 10), "the runner must report ready to `ruflet run`"
    assert_equal "t.", reader.read, "the runner reports its USR1 trap, then ready, then closes the fd"
    assert_nil ENV["RUFLET_READY_FD"], "the fd number must not leak to app subprocesses"
    assert @runner.watching?, "ready means the watcher and USR1 trap are armed"
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # The CLI's readiness fd reaches the app child without close-on-exec (spawn
  # maps it in), so anything the app spawned while loading inherited the pipe
  # and saw RUFLET_READY_FD; such a process could report "ready" early and
  # let a reload kill the booting app. The probe is a real subprocess that
  # the app script runs during load and that reports what it inherited.
  def test_processes_spawned_while_the_app_loads_do_not_inherit_the_ready_fd
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    writer.close_on_exec = false # as `ruflet run` hands it to the app child
    probe = File.join(@dir, "probe.rb")
    File.write(probe, <<~RUBY)
      begin
        IO.for_fd(Integer(ARGV[0]), autoclose: false)
        print "inherited"
      rescue Errno::EBADF
        print "closed"
      end
      print " env=", ENV["RUFLET_READY_FD"].inspect
    RUBY
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"
      $ready_fd_probe = `\#{RbConfig.ruby.inspect} \#{#{probe.inspect}.inspect} #{writer.fileno}`
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    assert IO.select([reader], nil, nil, 10), "the runner must still report ready"
    assert_equal "t.", reader.read
    assert_equal "closed env=nil", $ready_fd_probe
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # `ruflet run` holds "r" until the app reports, and falls back to sending
  # USR1 if the app is armed but never reports ready. That fallback is only
  # safe because the trap exists before any app code runs, which "t" says.
  def test_reports_the_usr1_trap_before_the_app_script_runs
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    $ready_reader = reader
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"
      $ready_bytes_at_load = $ready_reader.read_nonblock(8, exception: false)
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    assert_equal "t", $ready_bytes_at_load, "the trap must be reported before the app loads, and ready only after"
    assert IO.select([reader], nil, nil, 10), "the runner must report ready once the app is up"
    assert_equal ".", reader.read
  ensure
    ENV.delete("RUFLET_READY_FD")
    $ready_reader = nil
    reader&.close
  end

  # `Ruflet.app { ... }.run` starts Ruflet::Server directly instead of going
  # through Ruflet.run. The runner never saw it, so the app never reported
  # ready (`ruflet run` queued "r" forever) and file changes never reloaded.
  # It is now served the way it is without the runner: by its own server,
  # from inside its script, which goes on past `.run` only once that server
  # stops. Hot reload is armed around it.
  def test_a_dsl_app_is_served_by_its_own_server_with_hot_reload
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      $dsl_loads = ($dsl_loads || 0) + 1
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
      $dsl_after_run = true
    RUBY
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_served_runner

    assert_instance_of Ruflet::Server, @runner.server, "the app's own server serves it"
    assert_equal ["v1"], render_labels
    assert IO.select([reader], nil, nil, 10), "a DSL app must report ready to `ruflet run`"
    assert_equal "t.", reader.read
    assert_nil $dsl_after_run, "code after .run waits for the server, as without the runner"

    write_widgets("v2")
    wait_until("DSL reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels, "the app's server serves the reloaded block"
    assert_equal 2, $dsl_loads
    assert_nil $dsl_after_run, "a reload ends at .run, where the first load is still serving"

    stop_served_runner
    assert $dsl_after_run, "once its server stops, the script goes on as without the runner"
    refute @runner.watching?, "nothing reloads the app once its server has stopped"
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
    $dsl_loads = $dsl_after_run = nil
  end

  # Code after `.run` that blocks (joining a thread, a loop) is never
  # reached while the app is served, as without the runner. If the start
  # returned at once instead, that code would hold the load and the app
  # would never be served.
  def test_blocking_code_after_a_dsl_run_does_not_keep_the_app_from_being_served
    $after_run_gate = Queue.new
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      Ruflet.app(host: "127.0.0.1", port: 0) { text("served") }.run
      $after_run_gate.pop # like `worker.join` or `loop { sleep 1 }`
    RUBY

    start_served_runner

    assert_equal ["served"], render_labels
    @runner.request_reload
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["served"], render_labels, "the reload must not block in the code after .run either"
  ensure
    $after_run_gate&.push(:done)
    stop_served_runner
    $after_run_gate = nil
  end

  # A ruflet_core without Ruflet.with_run_interceptor starts the server from
  # Ruflet.run itself. The runner used to give up on hot reload there and
  # never report ready; that server is served with hot reload instead. With
  # no interceptor registered, this checkout's Ruflet.run takes that path.
  def test_ruflet_run_on_a_ruflet_core_without_run_interceptors_gets_hot_reload
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"

      Ruflet.run(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }
    RUBY
    without_run_interceptors do
      start_served_runner # the runner looks for run interceptors as it starts
    end

    assert_instance_of Ruflet::Server, @runner.server
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  end

  # The server the app built is the one that serves: a subclass keeps its
  # own behaviour, as without the runner.
  def test_an_app_server_subclass_serves_the_app
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      class HotReloadTestAppServer < Ruflet::Server
        def app_marker = :custom
      end
      HotReloadTestAppServer.new(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }.start
    RUBY

    start_served_runner

    assert_equal "HotReloadTestAppServer", @runner.server.class.name
    assert_equal :custom, @runner.server.app_marker
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  end

  # A script that keeps its server across loads (`$server ||= ...`) starts
  # the very server that serves it again on a reload: nothing to hand over,
  # and the block it serves must not end up calling itself.
  def test_a_reload_that_starts_the_serving_server_again_keeps_serving_it
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      $kept_server ||= Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }
      $kept_server.start
    RUBY

    start_served_runner

    assert_same $kept_server, @runner.server
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render, "the kept block reads the reloaded constant"
    assert_same $kept_server, @runner.server
  ensure
    stop_served_runner
    $kept_server = nil
  end

  # The runner's own server is a Ruflet::Server too; capturing its start
  # would leave the app with no server at all.
  def test_the_runners_own_server_still_starts
    require "ruflet_server"
    write_widgets("v1")
    write_main
    @runner = Ruflet::HotReload::Runner.new(
      script: @script,
      poll_interval: 0.05,
      server_factory: ->(host:, port:, &block) { Ruflet::Server.new(host: "127.0.0.1", port: 0, &block) },
      logger: ->(msg) { @logs << msg }
    )
    @thread = Thread.new { @runner.run }
    wait_until("own server bound") { @runner.server&.port.to_i.positive? }
    assert @runner.watching?
  ensure
    @runner&.server&.stop
    @thread&.join(2)
    @runner&.stop
    @runner = nil # already stopped
  end

  def test_server_start_outside_a_runner_is_untouched
    require "ruflet_server"
    Ruflet::HotReload.hook_server_start
    server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
    thread = Thread.new { server.start }
    wait_until("server bound") { server.port.to_i.positive? }
  ensure
    server&.stop
    thread&.join(2)
  end

  # Only a start the app script makes synchronously while the runner loads it
  # is the app's: without the runner that call blocks the load. Servers the
  # app starts on threads of its own, while its script goes on running, were
  # captured too and so never served. As on v0.0.23 they are the app's.
  def test_servers_the_app_starts_on_its_own_threads_are_served_by_the_app
    $thread_app_gate = Queue.new
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      $thread_app_servers = Array.new(2) { Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil } }
      $thread_app_servers.each { |server| Thread.new { server.start } }
      $thread_app_gate.pop # the script goes on, like `loop { sleep 1 }`
    RUBY
    @runner = new_runner
    @thread = Thread.new do
      Thread.current.report_on_exception = false
      @runner.run
    rescue Ruflet::HotReload::Error
      nil # no Ruflet.run once the gate opens; only the app's servers matter
    end
    wait_until("the app's own servers are bound") do
      $thread_app_servers&.all? { |server| server.port.to_i.positive? }
    end
    assert_nil @runner.server, "a start on the app's own thread must not be captured"
    refute @runner.watching?
  ensure
    Array($thread_app_servers).each(&:stop)
    $thread_app_gate&.push(:done)
    @thread&.join(5)
    $thread_app_servers = $thread_app_gate = nil
  end

  def test_a_thread_server_and_the_apps_main_server_are_both_served
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      unless $side_server
        $side_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
        Thread.new { $side_server.start }
      end
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    start_served_runner
    wait_until("the thread's server is bound") { $side_server&.port.to_i.positive? }

    refute_same $side_server, @runner.server, "the main thread's start is the app's"
    assert_equal ["v1"], render_labels
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
  ensure
    stop_served_runner
    $side_server&.stop
    $side_server = nil
  end

  # Without the runner the first start blocks, so the script reaches a
  # second one only once the first server stops; under the runner too. A
  # reload ends at the first start, so the second is not reached then either.
  def test_a_second_server_start_in_the_script_runs_once_the_first_server_stops
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      Ruflet.app(host: "127.0.0.1", port: 0) { text("first") }.run
      $second_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("second") }
      $second_server.start
    RUBY
    start_served_runner
    first = @runner.server

    assert_equal ["first"], render_labels
    @runner.request_reload
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["first"], render_labels
    assert_nil $second_server, "the second start is not reached while the first server serves"

    first.stop
    wait_until("the second server is bound") { $second_server&.port.to_i.positive? }
    assert_nil @runner.server, "the runner lets the stopped server go and leaves the second to the script"
  ensure
    $second_server&.stop
    stop_served_runner
    $second_server = nil
  end

  # On v0.0.23 a script that called Ruflet.run once its own server had
  # stopped had that Ruflet.run intercepted, and the runner's own server
  # served it after the load, with hot reload. It still does: the runner
  # lets the app's stopped server go instead of keeping it as the one it
  # serves.
  def test_ruflet_run_after_the_apps_own_server_stops_is_served_by_the_runner
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      unless $own_server
        $own_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("own") }
        $own_server.start
      end
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("the app's own server is bound") { $own_server&.port.to_i.positive? }
    assert_same $own_server, @runner.server
    assert_equal ["own"], render

    $own_server.stop
    wait_until("the runner's own server serves") { @runner.server.is_a?(FakeServer) && @runner.watching? }
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  ensure
    $own_server&.stop
    $own_server = nil
  end

  # On v0.0.23 a server the script starts itself after an intercepted
  # Ruflet.run blocked the load and served as is; the runner's own server
  # came up only once that one stopped. It still does.
  def test_a_server_started_after_an_intercepted_ruflet_run_runs_as_before
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      Ruflet.run { |page| page.add(WIDGET_LABEL) }
      $direct_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("direct") }
      $direct_server.start
    RUBY
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("the script's server is bound") { $direct_server&.port.to_i.positive? }
    assert_instance_of FakeServer, @runner.server
    refute @runner.watching?, "the script's own server holds the load, as on v0.0.23"

    $direct_server.stop
    wait_until("runner start") { @runner.watching? }
    assert_equal ["v1"], render
  ensure
    $direct_server&.stop
    $direct_server = nil
  end

  # A child the app forks while it loads runs the script's code in another
  # process; a server it starts is that process's, as without the runner.
  def test_a_server_started_in_a_child_the_app_forks_is_served_by_the_child
    skip "needs fork" unless Process.respond_to?(:fork)

    write_widgets("v1")
    reader, writer = IO.pipe
    $fork_report = writer
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      $forked_child = fork do
        begin
          server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
          Thread.new do
            sleep 0.01 until server.port.to_i.positive?
            $fork_report.write("bound")
            $fork_report.flush
          end
          server.start
          $fork_report.write("start returned")
        ensure
          exit!(0) # never run the test process's at_exit hooks in the child
        end
      end
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    start_runner
    writer.close

    assert IO.select([reader], nil, nil, 30), "the forked child must report"
    assert_equal "bound", reader.read(5), "the child's server must start, not be captured"
    assert_equal ["v1"], render
  ensure
    if $forked_child
      begin
        Process.kill("KILL", $forked_child)
        Process.wait($forked_child)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
    reader&.close
    writer&.close unless writer.nil? || writer.closed?
    $forked_child = $fork_report = nil
  end

  # `ruflet run` sends a queued "r" (USR1) once the app reports its trap, so
  # an app that could not trap USR1 must report nothing: USR1 would kill it.
  def test_nothing_is_reported_when_usr1_cannot_be_trapped
    write_widgets("v1")
    write_main
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s
    trap = Signal.method(:trap)
    refuse_usr1 = lambda do |signal, *rest, &handler|
      raise ArgumentError, "can't trap reserved signal: SIGUSR1" if signal.to_s == "USR1"

      trap.call(signal, *rest, &handler)
    end

    Signal.stub(:trap, refuse_usr1) do
      start_runner
      # Both trap attempts happen before the runner closes the fd.
      assert IO.select([reader], nil, nil, 10), "the runner must still close the fd"
      assert_equal "", reader.read, "no trap, no report"
    end
    assert_equal ["v1"], render, "the app itself still runs"
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # The runner must not load ruflet_server for the app: a DSL app that
  # never requires it fails the same way under the runner as under ruby.
  def test_the_runner_leaves_loading_ruflet_server_to_the_app
    File.write(@script, <<~RUBY)
      $stdout.write(defined?(Ruflet::Server).inspect)
      $stdout.flush
      require "ruflet"
      Ruflet.app { text("hi") }.run
    RUBY
    env = { "RUBYLIB" => [CORE_LIB, SERVER_LIB].join(File::PATH_SEPARATOR), "RUFLET_PORT" => "0" }
    harness = File.expand_path("../lib/ruflet/hot_reload/harness.rb", __dir__)

    reloaded = run_ruby(env.merge("RUFLET_APP_SCRIPT" => @script), harness)
    plain = run_ruby(env, @script)

    [["ruby", plain], ["the runner", reloaded]].each do |label, (out, err, status)|
      assert_equal "nil", out, "Ruflet::Server must not be loaded before the app under #{label}"
      assert_match(/uninitialized constant Ruflet::Server/, err, label)
      refute status.success?, label
    end
  end

  # In a fresh process the hook waits for the app to define Ruflet::Server,
  # and leaves alone the app classes it sees open on the way, even one that
  # defines its own `name`.
  def test_the_server_hook_waits_for_the_app_to_load_ruflet_server
    code = <<~RUBY
      require "ruflet/hot_reload"
      Ruflet::HotReload.hook_server_start
      print defined?(Ruflet::Server).inspect, " "
      class HookTestOddName
        def self.name(_required) = "odd"
      end
      class HookTestOddName; end # opened again, now with that `name`
      require "ruflet_server"
      print Ruflet::Server.ancestors.first(2).inspect
    RUBY
    env = { "RUBYLIB" => [File.expand_path("../lib", __dir__), CORE_LIB, SERVER_LIB].join(File::PATH_SEPARATOR) }

    out, err, status = run_ruby(env, "-e", code)

    assert status.success?, err
    assert_equal "nil [Ruflet::HotReload::ServerStartCapture, Ruflet::Server]", out
  end

  def test_without_the_cli_fd_nothing_is_reported
    write_widgets("v1")
    write_main
    ENV.delete("RUFLET_READY_FD")

    start_runner

    assert_equal ["v1"], render
  end

  def test_watched_files_excludes_vendored_and_hidden_paths
    write_widgets("v1")
    write_main
    vendored = File.join(@dir, "vendor", "bundle", "gem.rb")
    hidden = File.join(@dir, ".cache", "generated.rb")
    [vendored, hidden].each do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "# ignored\n")
    end

    runner = Ruflet::HotReload::Runner.new(script: @script, logger: ->(msg) { @logs << msg })
    watched = runner.watched_files

    assert_includes watched, @script
    assert_includes watched, File.join(@dir, "widgets.rb")
    refute_includes watched, vendored
    refute_includes watched, hidden
  end

  def test_script_that_never_calls_ruflet_run_raises
    File.write(@script, "# no Ruflet.run here\n")
    runner = Ruflet::HotReload::Runner.new(
      script: @script,
      server_factory: ->(host:, port:, &block) { FakeServer.new(&block) },
      logger: ->(msg) { @logs << msg }
    )

    error = assert_raises(Ruflet::HotReload::Error) { runner.run }
    assert_match(/never called Ruflet.run/, error.message)
  end

  def test_excluded_trees_are_not_traversed
    write_main
    ignored = %w[build vendor .cache node_modules].map { |name| File.join(@dir, name) }
    ignored.each do |path|
      FileUtils.mkdir_p(File.join(path, "deep"))
      File.write(File.join(path, "deep", "generated.rb"), "# ignored")
    end
    entered = []
    each_child = Dir.method(:each_child)
    Dir.stub(:each_child, ->(path, &block) { entered << path; each_child.call(path, &block) }) do
      runner = Ruflet::HotReload::Runner.new(script: @script)
      assert_equal [@script], runner.watched_files
    end
    assert_equal [@dir], entered
  end

  def test_nested_files_and_file_symlinks_are_watched_without_following_directory_links
    write_main
    nested = File.join(@dir, "lib", "widget.rb")
    FileUtils.mkdir_p(File.dirname(nested))
    File.write(nested, "# widget")
    alias_path = File.join(@dir, "alias.rb")
    File.symlink(nested, alias_path)
    File.symlink(@dir, File.join(@dir, "loop"))
    runner = Ruflet::HotReload::Runner.new(script: @script)
    assert_equal [@script, nested, alias_path].sort, runner.watched_files
  end

  def test_explicit_entrypoint_is_kept_when_outside_watch_root
    write_main
    root = File.join(@dir, "lib")
    FileUtils.mkdir_p(root)
    runner = Ruflet::HotReload::Runner.new(script: @script, watch_root: root)
    assert_equal [@script], runner.watched_files
  end

  def test_directory_removed_during_snapshot_does_not_stop_watcher
    write_main
    removed = File.join(@dir, "removed")
    FileUtils.mkdir_p(removed)
    each_child = Dir.method(:each_child)
    Dir.stub(:each_child, lambda { |path, &block|
      raise Errno::ENOENT, path if path == removed
      each_child.call(path, &block)
    }) do
      runner = Ruflet::HotReload::Runner.new(script: @script)
      assert_equal [@script], runner.watched_files
    end
  end

  private

  def write_main
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"

      Ruflet.run do |page|
        page.add(WIDGET_LABEL)
      end
    RUBY
  end

  def write_widgets(label)
    File.write(File.join(@dir, "widgets.rb"), "WIDGET_LABEL = #{label.inspect}\n")
  end

  def new_runner
    Ruflet::HotReload::Runner.new(
      script: @script,
      poll_interval: 0.05,
      server_factory: ->(host:, port:, &block) { FakeServer.new(&block) },
      logger: ->(msg) { @logs << msg }
    )
  end

  def start_runner
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("runner start") { @runner.watching? }
  end

  # [stdout, stderr, status] of a fresh Ruby; the limit only stops a
  # regression (an app that ends up served) from hanging the suite.
  def run_ruby(env, *args, timeout: 60)
    out_reader, out_writer = IO.pipe
    err_reader, err_writer = IO.pipe
    pid = Process.spawn(env, RbConfig.ruby, *args, out: out_writer, err: err_writer, pgroup: true)
    [out_writer, err_writer].each(&:close)
    out = Thread.new { out_reader.read }
    err = Thread.new { err_reader.read }
    status = Timeout.timeout(timeout) { Process.wait2(pid).last }
    [out.value, err.value, status]
  rescue Timeout::Error
    Process.kill("KILL", -pid)
    Process.wait(pid)
    flunk "#{args.last} never exited"
  ensure
    [out_reader, err_reader].each { |io| io&.close }
  end

  # Starts the runner for an app its own Ruflet::Server serves, and waits
  # until that server is bound.
  def start_served_runner
    start_runner
    wait_until("the app's server is bound") { @runner.server.port.to_i.positive? }
  end

  # Stops the server serving the app; the script then goes on and the
  # runner returns, as without the runner.
  def stop_served_runner
    server = @runner&.server
    server.is_a?(FakeServer) ? server.shutdown : server&.stop
    @thread&.join(10)
  end

  # What the server serving the app calls for each session.
  def served_block
    server = @runner.server
    server.is_a?(FakeServer) ? server.app_block : server.instance_variable_get(:@app_block)
  end

  def render
    page = RecorderPage.new
    served_block.call(page)
    page.added
  end

  def render_labels
    page = RecorderPage.new
    served_block.call(page)
    page.labels
  end

  # Simulates a ruflet_core from before Ruflet.with_run_interceptor existed.
  def without_run_interceptors
    singleton = Ruflet.singleton_class
    singleton.send(:alias_method, :__test_with_run_interceptor, :with_run_interceptor)
    singleton.send(:remove_method, :with_run_interceptor)
    yield
  ensure
    singleton.send(:alias_method, :with_run_interceptor, :__test_with_run_interceptor)
    singleton.send(:remove_method, :__test_with_run_interceptor)
  end

  def wait_until(what, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until (value = yield)
      flunk "timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.02
    end
    value
  end
end
