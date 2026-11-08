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
      @started = false
    end

    # The runner starts its server only once it has armed hot reload and
    # reported ready.
    def started?
      @started
    end

    def start
      @started = true
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

  # The same on a ruflet_core without run interceptors, whose apps the
  # runner serves another way: without "t" such an app that never reports
  # ready would never get the fallback either.
  def test_reports_the_usr1_trap_before_the_app_script_runs_on_a_ruflet_core_without_run_interceptors
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    $ready_reader = reader
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"
      $ready_bytes_at_load = $ready_reader.read_nonblock(8, exception: false)
      Ruflet.run(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }
    RUBY
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    without_run_interceptors do
      start_served_runner # the runner looks for run interceptors as it starts
    end

    assert_equal "t", $ready_bytes_at_load, "the trap must be reported before the app loads"
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

  # The same without the guard. A reload runs the script from the top, so it
  # reaches that start again first. It used to hand the stopped server's
  # block over, and the reload repainted "own" instead of the Ruflet.run
  # block the runner serves; on v0.0.23 and main it started that server
  # again on the watcher thread, and the reload never finished. On the first
  # load that start returned once its server stopped, so on a reload it
  # returns at once, starting nothing, and the load goes on to Ruflet.run,
  # as under plain ruby once that server has stopped.
  def test_ruflet_run_after_the_apps_unguarded_own_server_stops_is_served_by_the_runner
    $own_servers = []
    $after_own_start = 0
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      $own_servers << Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("own") }
      $own_servers.last.start
      $after_own_start += 1
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("the app's own server is bound") { $own_servers.first&.port.to_i.positive? }
    assert_equal ["own"], render

    $own_servers.first.stop
    wait_until("the runner's own server serves") { @runner.server.is_a?(FakeServer) && @runner.watching? }
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render, "the reload serves the new Ruflet.run block"
    assert_equal 2, $own_servers.size
    assert_equal 0, $own_servers.last.port, "the reload's start returns without starting that server"
    assert_equal 2, $after_own_start, "and the load goes on past it"

    @runner.request_reload
    wait_until("the second reload") { @runner.reload_count >= 2 }
    assert_equal ["v2"], render
  ensure
    $own_servers&.each(&:stop)
    $own_servers = $after_own_start = nil
  end

  # On v0.0.23 a server the script starts itself after an intercepted
  # Ruflet.run blocked the load and served as is; the runner's own server
  # came up only once that one stopped. It still does. On a reload, too,
  # the load's first entrypoint is the app's: the later start ends the load
  # and hands nothing over.
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

    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render, "the reloaded Ruflet.run block is served, not the later server's"
    assert_equal 0, $direct_server.port, "the reload ends at the later start without starting that server"
  ensure
    $direct_server&.stop
    $direct_server = nil
  end

  # A start on the script's fiber after the runner already holds a server
  # (from a Ruflet.run the app made on a thread of its own) is not the
  # load's first entrypoint either: as on v0.0.23 it blocks the load and
  # serves as is, and the runner's server comes up once it stops.
  def test_a_server_started_after_a_ruflet_run_on_an_app_thread_runs_as_before
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      Thread.new { Ruflet.run { |page| page.add(WIDGET_LABEL) } }.join
      $direct_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("direct") }
      $direct_server.start
    RUBY
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("the script's server is bound") { $direct_server&.port.to_i.positive? }
    assert_instance_of FakeServer, @runner.server, "the thread's Ruflet.run is the app's"
    refute @runner.watching?, "the script's own server holds the load, as on v0.0.23"

    $direct_server.stop
    wait_until("runner start") { @runner.watching? }
    assert_equal ["v1"], render
  ensure
    $direct_server&.stop
    $direct_server = nil
  end

  # The embedded runtime's transport: a server with an in-process bridge is
  # never the app's dev server, so it runs exactly as without the runner.
  def test_a_server_with_an_in_process_bridge_is_not_captured
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      $bridge_server = Ruflet::Server.new(host: "127.0.0.1", port: 0, in_process_bridge: Object.new) { |_page| nil }
      $bridge_server.start
    RUBY
    @runner = new_runner
    @thread = Thread.new do
      Thread.current.report_on_exception = false
      @runner.run
    rescue Ruflet::HotReload::Error
      nil # once that server stops, the script has handed nothing over
    end
    # Without RUFLET_RUNTIME_TRANSPORT=in_process it listens on a socket.
    wait_until("the bridge server is bound") { $bridge_server&.port.to_i.positive? }
    assert_nil @runner.server, "a server with an in-process bridge must not be captured"
    refute @runner.watching?
  ensure
    $bridge_server&.stop
    @thread&.join(5)
    $bridge_server = nil
  end

  # Serving is not loading. While the app's own server serves, the app runs
  # as without the runner: its warnings show again ($VERBOSE is its own;
  # only the load silences it), and code on the serving fiber is outside the
  # script load, so nothing it does there is the runner's to capture. Once
  # that server stops, the rest of the script is loading again, and runs
  # with warnings silenced, as on v0.0.23.
  def test_while_the_apps_own_server_serves_the_app_runs_as_without_the_runner
    $serving_probe = Queue.new
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      $verbose_while_loading = $VERBOSE
      class HotReloadTestServingProbe < Ruflet::Server
        private def accept_loop
          $serving_probe << [$VERBOSE, Thread.current[Ruflet::HotReload::SERVER_START_CAPTURE]]
          super
        end
      end
      HotReloadTestServingProbe.new(host: "127.0.0.1", port: 0) { |page| page.add("served") }.start
      $verbose_after_start = [$VERBOSE]
    RUBY
    previous_verbose = $VERBOSE
    $VERBOSE = true

    start_served_runner
    wait_until("the app's server serves") { !$serving_probe.empty? }
    verbose, capture = $serving_probe.pop

    assert_nil $verbose_while_loading, "the load silences warnings, as on v0.0.23"
    assert_equal true, verbose, "while its server serves, the app's own $VERBOSE is back"
    assert_nil capture, "the serving fiber is no longer loading the script"

    stop_served_runner
    assert_equal [nil], $verbose_after_start, "the code after the start runs in the load, as on v0.0.23"
    assert_equal true, $VERBOSE, "the runner restores the $VERBOSE it found once the load ends"
  ensure
    stop_served_runner
    $VERBOSE = previous_verbose
    $serving_probe = $verbose_while_loading = $verbose_after_start = nil
  end

  # A script that sets $VERBOSE itself while it loads keeps that setting
  # while its own server serves and after it, as on v0.0.23.
  def test_a_verbose_setting_the_script_makes_is_kept_while_its_own_server_serves
    $serving_probe = Queue.new
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"

      $VERBOSE = false
      class HotReloadTestVerboseProbe < Ruflet::Server
        private def accept_loop
          $serving_probe << $VERBOSE
          super
        end
      end
      HotReloadTestVerboseProbe.new(host: "127.0.0.1", port: 0) { |page| page.add("served") }.start
      $verbose_after_start = [$VERBOSE]
    RUBY
    previous_verbose = $VERBOSE
    $VERBOSE = true

    start_served_runner
    wait_until("the app's server serves") { !$serving_probe.empty? }
    assert_equal false, $serving_probe.pop, "the script's own $VERBOSE = false holds while its server serves"

    stop_served_runner
    assert_equal [false], $verbose_after_start
  ensure
    stop_served_runner
    $VERBOSE = previous_verbose
    $serving_probe = $verbose_after_start = nil
  end

  # A child the app forks while it loads runs the script's code in another
  # process; a server it starts is that process's, as without the runner:
  # the child arms no hot reload of its own and never reports to `ruflet
  # run` on the ready fd it inherited.
  def test_a_server_started_in_a_child_the_app_forks_is_served_by_the_child
    skip "needs fork" unless Process.respond_to?(:fork)

    write_widgets("v1")
    reader, writer = IO.pipe
    ready_reader, ready_writer = IO.pipe
    ready_writer.autoclose = false # the runner owns and closes this fd
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
            $fork_report.write($fork_runner.watching? ? "watched" : "unarmed")
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
    ENV["RUFLET_READY_FD"] = ready_writer.fileno.to_s
    @runner = $fork_runner = new_runner
    @thread = Thread.new { @runner.run }
    # The runner starts its server only after it has reported ready.
    wait_until("the runner's server starts") { @runner.server.is_a?(FakeServer) && @runner.server.started? }
    writer.close

    assert IO.select([reader], nil, nil, 30), "the forked child must report"
    assert_equal "unarmed", reader.read(7), "the child's server must start as is, without the runner's hot reload"
    assert_equal ["v1"], render
    # The child holds its copy of the ready fd open, so read what is there:
    # the child wrote whatever it did before it reported above.
    reported = +""
    while (bytes = ready_reader.read_nonblock(16, exception: false)).is_a?(String)
      reported << bytes
    end
    assert_equal "t.", reported, "only the runner reports on the ready fd"
  ensure
    ENV.delete("RUFLET_READY_FD")
    ready_reader&.close
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
    $forked_child = $fork_report = $fork_runner = nil
  end

  # main.rb requires app.rb, which ends with `Ruflet.app { ... }.run`: the
  # app's own server then serves from inside app.rb's require, and Ruby
  # holds that require's lock until the server stops. A reload loads main.rb
  # again on the watcher thread, and its `require_relative "app"` waited on
  # that lock forever: no later save or "r" reloaded, and nothing was
  # logged. A reload now loads app.rb there instead.
  def test_a_dsl_app_started_in_a_file_the_script_requires_reloads
    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      $app_loads = ($app_loads || 0) + 1
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
      $app_after_run = true
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
      $main_after_require = true
    RUBY

    start_served_runner
    assert_equal ["v1"], render_labels

    write_widgets("v2")
    wait_until("the reload on save") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels, "the save reloads app.rb and the file it requires"
    @runner.request_reload
    wait_until("the reload on r") { @runner.reload_count >= 2 }
    assert_equal ["v2"], render_labels
    assert_equal 3, $app_loads
    assert_nil $app_after_run, "a reload ends at .run, where the first load is still serving"
    assert_nil $main_after_require

    stop_served_runner
    assert $app_after_run, "once its server stops, app.rb goes on, as without the runner"
    assert $main_after_require, "and so does main.rb"
    refute @runner.watching?
  ensure
    $app_loads = $app_after_run = $main_after_require = nil
  end

  # The same with Ruflet::Server started directly, in a file found on the
  # load path (`require "app_server"`).
  def test_a_server_started_in_a_file_required_from_the_load_path_reloads
    write_widgets("v1")
    write_file("app_server.rb", <<~RUBY)
      require "widgets"
      Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }.start
    RUBY
    File.write(@script, <<~RUBY)
      $LOAD_PATH.unshift(#{@dir.inspect}) unless $LOAD_PATH.include?(#{@dir.inspect})
      require "ruflet"
      require "ruflet_server"
      require "app_server"
    RUBY

    start_served_runner
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  ensure
    $LOAD_PATH.delete(@dir)
  end

  # Every file between the script and the start is in its require: main.rb
  # requires lib/boot.rb, which requires app.rb, which starts the server.
  def test_a_start_required_through_a_chain_of_files_reloads
    write_widgets("v1")
    FileUtils.mkdir_p(File.join(@dir, "lib"))
    write_file("lib/boot.rb", <<~RUBY)
      $boot_loads = ($boot_loads || 0) + 1
      require_relative "../app"
    RUBY
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "lib/boot"
    RUBY

    start_served_runner
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
    assert_equal 2, $boot_loads
  ensure
    $boot_loads = nil
  end

  # On v0.0.23 a Ruflet.run in a file the script requires reloaded: the
  # interceptor returns at once, so that require completes. It still does.
  def test_ruflet_run_in_a_file_the_script_requires_reloads
    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "app"
    RUBY

    start_runner
    assert_instance_of FakeServer, @runner.server
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  end

  # On a ruflet_core without run interceptors that Ruflet.run starts the
  # server itself, from inside the require.
  def test_ruflet_run_in_a_required_file_on_a_ruflet_core_without_run_interceptors_reloads
    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.run(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "app"
    RUBY
    without_run_interceptors do
      start_served_runner # the runner looks for run interceptors as it starts
    end

    assert_instance_of Ruflet::Server, @runner.server
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  end

  # `ruflet run` sets bootsnap up whenever it is installed. Its compile
  # cache hands Ruby precompiled code, whose top-level frames do not read
  # "<top (required)>"; a required file must still be found. These two are
  # what bootsnap's cache does, minus the cache: compile_file labels the
  # frame "<main>" (bootsnap on most Rubies), and compiling the file's
  # source labels it "<compiled>", as bootsnap does on Rubies with Ruby bug
  # #22023 (3.3, 3.4.0-3.4.9 and 4.0.0-4.0.3 with Prism).
  def test_a_start_in_a_required_file_compiled_by_a_compile_cache_reloads
    assert_compiled_start_reloads("<main>") { |path| RubyVM::InstructionSequence.compile_file(path) }
  end

  def test_a_start_in_a_required_file_compiled_from_source_by_a_compile_cache_reloads
    assert_compiled_start_reloads("<compiled>") do |path|
      RubyVM::InstructionSequence.compile(File.read(path), path, path)
    end
  end

  def assert_compiled_start_reloads(label, &compiler)
    iseq = RubyVM::InstructionSequence.singleton_class
    skip "a compile cache is already installed" if iseq.method_defined?(:load_iseq)

    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      $app_top_label = caller_locations(0, 1).first.label
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
    RUBY
    iseq.define_method(:load_iseq, &compiler)

    start_served_runner
    assert_equal label, $app_top_label, "the cache must compile the app's files"
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
  ensure
    stop_served_runner
    iseq.send(:remove_method, :load_iseq) if iseq&.method_defined?(:load_iseq)
    $app_top_label = nil
  end

  # The script's own top level is its bottom-most frame, whatever its label,
  # not the first frame in it: here a method main.rb defines starts the app
  # from inside lib/boot.rb's require, so that require is in flight too.
  def test_a_start_from_a_script_method_called_by_a_required_file_reloads
    write_widgets("v1")
    FileUtils.mkdir_p(File.join(@dir, "lib"))
    write_file("lib/boot.rb", <<~RUBY)
      $boot_loads = ($boot_loads || 0) + 1
      hot_reload_test_serve_the_app
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      def hot_reload_test_serve_the_app
        Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
      end
      require_relative "lib/boot"
    RUBY

    start_served_runner
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
    assert_equal 2, $boot_loads
  ensure
    $boot_loads = nil
  end

  # Only a reload of an app served from inside a required file needs its
  # requires loaded instead, and only while it runs: otherwise Kernel's own
  # require and require_relative are the ones every caller gets.
  def test_require_is_wrapped_only_while_a_reload_needs_it
    write_widgets("v1")
    $require_owners = []
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      $require_owners << [Object.instance_method(:require).owner, Object.instance_method(:require_relative).owner]
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
    RUBY

    start_served_runner
    @runner.request_reload
    wait_until("reload") { @runner.reload_count >= 1 }

    wrapped = Ruflet::HotReload::InFlightRequires
    assert_equal [[Kernel, Kernel], [wrapped, wrapped]], $require_owners
    assert_equal [Kernel, Kernel], [Object.instance_method(:require).owner, Object.instance_method(:require_relative).owner],
                 "once the reload is done, require is Kernel's own again"
  ensure
    $require_owners = nil
  end

  # The script itself is loaded, not required, so it holds no require lock;
  # nor does the code that runs the runner, which the harness runs from its
  # own top level, as here.
  def test_a_reload_of_an_app_served_from_its_main_script_leaves_require_alone
    write_widgets("v1")
    $require_owners = []
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"
      $require_owners << Object.instance_method(:require).owner
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    launcher = File.join(Dir.mktmpdir("ruflet-hot-reload-launcher-"), "launcher.rb")
    File.write(launcher, "$hot_reload_test_runner.run\n")
    @runner = $hot_reload_test_runner = new_runner
    @thread = Thread.new { load launcher }
    wait_until("the app's server is bound") { @runner.server&.port.to_i.positive? }

    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
    assert_equal [Kernel, Kernel], $require_owners, "nothing on the serving fiber's stack holds a require lock"
  ensure
    stop_served_runner
    FileUtils.remove_entry(File.dirname(launcher)) if launcher
    $require_owners = $hot_reload_test_runner = nil
  end

  # A file in flight is loaded where the script requires it, as `require`
  # would: once per load, returning true and then false. Here the start
  # moves from app.rb to main.rb, which requires app.rb twice.
  def test_a_file_in_flight_is_loaded_once_per_reload
    write_file("app.rb", <<~RUBY)
      $app_loads = ($app_loads || 0) + 1
      Ruflet.app(host: "127.0.0.1", port: 0) { text("from app") }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      $app_required = [require_relative("app")]
      $app_required << require_relative("app")
      $main_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("from main") }
      $main_server.start
    RUBY

    start_served_runner
    assert_equal ["from app"], render_labels
    write_file("app.rb", "$app_loads = ($app_loads || 0) + 1\n")
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["from main"], render
    assert_equal 2, $app_loads, "the second require of app.rb in the reload must not load it again"
    assert_equal [true, false], $app_required, "as require reports it: loaded, then already loaded"

    # Once app.rb's server stops, the first load goes on to main.rb's own
    # start, which then runs as is; stopped here, so the runner returns.
    @runner.server.stop
    wait_until("main.rb's own server is bound") { $main_server&.port.to_i.positive? }
    $main_server.stop
    @thread.join(5)
    refute @thread.alive?
  ensure
    $main_server&.stop
    $app_loads = $app_required = $main_server = nil
  end

  # As with `require`, a file in flight whose load raised is loaded again by
  # a later require in the same load.
  def test_a_file_in_flight_that_raised_is_loaded_again_by_a_later_require
    write_file("app.rb", <<~RUBY)
      $app_loads = ($app_loads || 0) + 1
      Ruflet.app(host: "127.0.0.1", port: 0) { text("v1") }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      begin
        require_relative "app"
      rescue RuntimeError
        require_relative "app"
      end
    RUBY

    start_served_runner
    write_file("app.rb", <<~RUBY)
      $app_loads = ($app_loads || 0) + 1
      raise "first try" if $app_loads == 2
      Ruflet.app(host: "127.0.0.1", port: 0) { text("v2") }.run
    RUBY
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["v2"], render_labels
    assert_equal 3, $app_loads
  ensure
    $app_loads = nil
  end

  # Once the app's own server stops, its requires complete; later reloads
  # require those files as Ruby always does.
  def test_files_are_required_again_once_the_apps_own_server_stops
    write_widgets("v1")
    app = File.join(@dir, "app.rb")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      unless $own_server
        $own_server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |page| page.add("own") }
        $own_server.start
      end
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
    RUBY
    @runner = new_runner
    @thread = Thread.new { @runner.run }
    wait_until("the app's own server is bound") { $own_server&.port.to_i.positive? }

    $own_server.stop
    wait_until("the runner's own server serves") { @runner.server.is_a?(FakeServer) && @runner.watching? }
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["v2"], render
    assert($LOADED_FEATURES.any? { |feature| real_path(feature) == real_path(app) },
           "the reload requires app.rb, as Ruby records it")
  ensure
    $own_server&.stop
    $own_server = nil
  end

  # Zeitwerk and bootsnap alias Kernel#require. One loaded for the first
  # time during such a reload must leave require working once it is done.
  # In a fresh process: the alias stays in it for good.
  def test_a_gem_that_aliases_kernel_require_during_such_a_reload_keeps_require_working
    write_widgets("v1")
    write_file("late_patch.rb", <<~RUBY)
      module Kernel
        alias_method :__hot_reload_test_late_require, :require
        def require(path)
          ($late_requires ||= []) << path
          __hot_reload_test_late_require(path)
        end
        private :require, :__hot_reload_test_late_require
      end
    RUBY
    write_file("fresh.rb", "$fresh_loaded = true\n")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      require_relative "late_patch" if $patch_on_reload && !$patched
      $patched = true if $patch_on_reload
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
    RUBY
    driver = <<~'RUBY'
      require "ruflet/hot_reload"
      def wait_for(what)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
        until yield
          abort "timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.02
        end
      end
      runner = Ruflet::HotReload::Runner.new(script: ENV.fetch("TEST_SCRIPT"), poll_interval: 0.05, logger: ->(m) { warn m })
      thread = Thread.new { runner.run }
      wait_for("the app's server") { runner.server&.port.to_i.positive? }
      $patch_on_reload = true
      runner.request_reload
      wait_for("the reload that patches require") { runner.reload_count >= 1 }
      print require(File.join(ENV.fetch("TEST_DIR"), "fresh")), " ", $late_requires.to_a.size.positive?, " "
      runner.request_reload
      wait_for("the next reload") { runner.reload_count >= 2 }
      print runner.reload_count
      runner.server.stop
      thread.join
    RUBY
    env = {
      "RUBYLIB" => [File.expand_path("../lib", __dir__), CORE_LIB, SERVER_LIB].join(File::PATH_SEPARATOR),
      "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
      "TEST_SCRIPT" => @script,
      "TEST_DIR" => @dir
    }

    out, err, status = run_ruby(env, "-e", driver)

    assert status.success?, err
    assert_equal "true true 2", out
    refute_match(/reload failed/, err)
  end

  # Only the reloading fiber loads the files in flight. A `require` or
  # `require_relative` of one on any other thread during the reload goes to
  # Kernel's own, which waits on that file's require lock, as it always has,
  # until the app's own server stops.
  def test_a_require_on_another_thread_during_such_a_reload_goes_to_kernels_require
    write_widgets("v1")
    $app_loaders = []
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      $app_loaders << Thread.current
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    # The path require_relative gives Kernel's require, so both wait on the
    # same lock.
    app_feature = File.join(real_path(@dir), "app")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      if $start_other_requirers && $other_requirers.nil?
        $other_requirers = [
          Thread.new { require_relative "app" },
          Thread.new { require #{app_feature.inspect} }
        ]
        sleep 0.01 until $other_requirers.all?(&:stop?)
      end
      require_relative "app"
    RUBY

    start_served_runner
    $start_other_requirers = true
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["v2"], render_labels, "the reloading fiber loads app.rb and reaches the start"
    assert_equal 2, $app_loaders.size
    $other_requirers.each do |thread|
      refute_includes $app_loaders, thread, "another thread must not load app.rb itself"
      assert thread.alive?, "it waits on app.rb's require, as without the runner"
    end

    stop_served_runner
    assert_equal [false, false], $other_requirers.map { |thread| thread.join(5)&.value },
                 "once app.rb's require is done, it is already loaded"
  ensure
    $other_requirers&.each(&:kill)
    $app_loaders = $start_other_requirers = $other_requirers = nil
  end

  # Only the files in flight themselves are loaded instead. A `require "app"`
  # that finds another app.rb on the load path requires that file as Ruby
  # always does, also while this app's app.rb is in flight.
  def test_another_file_with_the_name_of_a_file_in_flight_is_required_as_usual
    write_widgets("v1")
    other_dir = Dir.mktmpdir("ruflet-hot-reload-other-")
    File.write(File.join(other_dir, "app.rb"), "$other_app_loads = ($other_app_loads || 0) + 1\n")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      $LOAD_PATH.unshift(#{other_dir.inspect}) unless $LOAD_PATH.include?(#{other_dir.inspect})
      require "ruflet"
      require "ruflet_server"
      $other_app_required = require "app"
      require_relative "app"
    RUBY

    start_served_runner
    assert_equal true, $other_app_required
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["v2"], render_labels
    assert_equal 1, $other_app_loads, "the other app.rb is required, so the reload does not load it again"
    assert_equal false, $other_app_required
  ensure
    $LOAD_PATH.delete(other_dir)
    FileUtils.remove_entry(other_dir) if other_dir
    $other_app_loads = $other_app_required = nil
  end

  # A file system that does not tell "App" from "app" (macOS by default)
  # lets `require_relative "App"` load app.rb. That require is in flight too.
  def test_a_file_in_flight_required_in_another_case_reloads
    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    skip "this file system tells App.rb from app.rb" unless File.exist?(File.join(@dir, "App.rb"))

    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "App"
    RUBY

    start_served_runner
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
  end

  # `require_relative` during such a reload resolves as Kernel's does: from
  # eval'd code it raises the same LoadError.
  def test_require_relative_from_eval_during_such_a_reload_raises_as_kernels_does
    write_widgets("v1")
    $eval_errors = []
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      $eval_errors << begin
        eval('require_relative "app"')
      rescue LoadError => e
        e.message
      end
      require_relative "app"
    RUBY

    start_served_runner
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }

    assert_equal ["v2"], render_labels
    assert_equal 2, $eval_errors.size
    assert_kind_of String, $eval_errors.first, "Kernel's require_relative raises from eval'd code"
    assert_equal $eval_errors.first, $eval_errors.last, "the reload's require_relative raises the same"
  ensure
    $eval_errors = nil
  end

  # Kernel#require_relative calls the interpreter's own require, never a
  # Kernel#require wrapper such as bootsnap's, which the harness sets up
  # before it loads the runner. During such a reload it still does. In a
  # fresh process, so the wrapper exists before the runner is loaded.
  def test_require_relative_during_such_a_reload_bypasses_kernel_require_wrappers
    write_widgets("v1")
    write_file("app.rb", <<~RUBY)
      require_relative "widgets"
      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "app"
    RUBY
    driver = <<~'RUBY'
      module Kernel
        alias_method :__hot_reload_test_wrapped_require, :require
        def require(path)
          ($wrapped_requires ||= []) << path.to_s
          __hot_reload_test_wrapped_require(path)
        end
        private :require, :__hot_reload_test_wrapped_require
      end
      require "ruflet/hot_reload"
      def wait_for(what)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 20
        until yield
          abort "timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.02
        end
      end
      runner = Ruflet::HotReload::Runner.new(script: ENV.fetch("TEST_SCRIPT"), poll_interval: 0.05, logger: ->(m) { warn m })
      thread = Thread.new { runner.run }
      wait_for("the app's server") { runner.server&.port.to_i.positive? }
      app_files = ->(paths) { paths.select { |path| File.basename(path, ".rb") == "widgets" } }
      first_load = app_files.call($wrapped_requires)
      $wrapped_requires = []
      runner.request_reload
      wait_for("the reload") { runner.reload_count >= 1 }
      print first_load.inspect, " ", app_files.call($wrapped_requires).inspect, " ", runner.reload_count
      runner.server.stop
      thread.join
    RUBY
    env = {
      "RUBYLIB" => [File.expand_path("../lib", __dir__), CORE_LIB, SERVER_LIB].join(File::PATH_SEPARATOR),
      "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
      "TEST_SCRIPT" => @script
    }

    out, err, status = run_ruby(env, "-e", driver)

    assert status.success?, err
    assert_equal "[] [] 1", out, "neither the first load's require_relative nor the reload's calls Kernel#require"
    refute_match(/reload failed/, err)
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
  # defines its own `name`. Once it has hooked the class, its trace is off:
  # it costs nothing for the rest of the process.
  def test_the_server_hook_waits_for_the_app_to_load_ruflet_server
    code = <<~RUBY
      require "ruflet/hot_reload"
      Ruflet::HotReload.hook_server_start
      watch = Ruflet::HotReload.instance_variable_get(:@server_class_watch)
      print defined?(Ruflet::Server).inspect, " ", watch.enabled?, " "
      class HookTestOddName
        def self.name(_required) = "odd"
      end
      class HookTestOddName; end # opened again, now with that `name`
      require "ruflet_server"
      print Ruflet::Server.ancestors.first(2).inspect, " ", watch.enabled?
    RUBY
    env = { "RUBYLIB" => [File.expand_path("../lib", __dir__), CORE_LIB, SERVER_LIB].join(File::PATH_SEPARATOR) }

    out, err, status = run_ruby(env, "-e", code)

    assert status.success?, err
    assert_equal "nil true [Ruflet::HotReload::ServerStartCapture, Ruflet::Server] false", out
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
    write_file("widgets.rb", "WIDGET_LABEL = #{label.inspect}\n")
  end

  def write_file(name, source)
    File.write(File.join(@dir, name), source)
  end

  def real_path(path)
    File.realpath(path)
  rescue SystemCallError
    path
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
