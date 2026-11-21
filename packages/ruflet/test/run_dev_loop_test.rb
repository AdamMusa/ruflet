# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "rbconfig"
require "socket"
require "timeout"

# The `ruflet run` dev loop around the app child: how it is spawned and
# stopped on each host, which port it gets, and what happens when the app
# exits before its server is up.
class RufletCliRunDevLoopTest < Minitest::Test
  class DummyRunner
    include Ruflet::CLI::RunCommand
  end

  # --- spawning and stopping the app child -----------------------------------

  def test_the_app_child_leads_a_new_process_group_on_windows_ruby
    %w[mingw32 x64-mingw-ucrt mswin64_140].each do |host_os|
      with_host_os(host_os) do
        assert_equal({ new_pgroup: true }, DummyRunner.new.send(:app_child_group_options), host_os)
      end
    end
  end

  # Cygwin's Ruby is POSIX: it has setpgid and keeps `pgroup:`.
  def test_the_app_child_keeps_pgroup_on_posix_hosts
    %w[darwin25 linux-gnu cygwin].each do |host_os|
      with_host_os(host_os) do
        assert_equal({ pgroup: true }, DummyRunner.new.send(:app_child_group_options), host_os)
      end
    end
  end

  # The POSIX spawn is the call it always was, with and without the ready pipe.
  def test_spawn_app_child_passes_pgroup_exactly_as_before_on_posix
    with_host_os("darwin25") do
      [false, true].each do |track_ready|
        runner = DummyRunner.new
        run_state = runner.send(:new_run_state, track_ready: track_ready)
        seen = []
        fake_spawn = lambda do |*args, **options|
          seen << [args, options]
          4242
        end
        Process.stub(:spawn, fake_spawn) do
          assert_equal 4242, runner.send(:spawn_app_child, { "A" => "1" }, %w[ruby app.rb], run_state, out: File::NULL)
        end
        run_state[:ready_thread]&.join

        args, options = seen.fetch(0)
        assert_equal [{ "A" => "1" }, "ruby", "app.rb"], args.map { |arg| arg.is_a?(Hash) ? arg.reject { |key, _| key == "RUFLET_READY_FD" } : arg }
        expected_keys = track_ready ? [:pgroup, Ruflet::CLI::RunCommand::READY_FD, :out] : %i[pgroup out]
        assert_equal expected_keys, options.keys, "track_ready=#{track_ready}"
        assert_equal true, options[:pgroup]
      end
    end
  end

  def test_signal_app_child_signals_the_process_group_on_posix
    with_host_os("darwin25") do
      kills = []
      Process.stub(:kill, ->(signal, *pids) { kills << [signal, *pids]; 1 }) do
        DummyRunner.new.send(:signal_app_child, "TERM", { child_pid: 4242, reaped_pid: 4242 })
      end
      assert_equal [["TERM", -4242]], kills, "POSIX keeps the group signal it always sent, reaped or not"
    end
  end

  def test_signal_app_child_ends_the_process_tree_on_windows
    with_host_os("mingw32") do
      runner = DummyRunner.new
      commands = record_system(runner, result: true)
      kills = []
      Process.stub(:kill, ->(signal, *pids) { kills << [signal, *pids]; 1 }) do
        runner.send(:signal_app_child, "INT", { child_pid: 4242 })
      end
      assert_equal [["taskkill", "/T", "/F", "/PID", "4242"]], commands
      assert_empty kills
    end
  end

  def test_signal_app_child_falls_back_to_kill_without_taskkill_on_windows
    with_host_os("mingw32") do
      runner = DummyRunner.new
      record_system(runner, result: nil)
      kills = []
      Process.stub(:kill, ->(signal, *pids) { kills << [signal, *pids]; 1 }) do
        runner.send(:signal_app_child, "TERM", { child_pid: 4242 })
      end
      assert_equal [["KILL", 4242]], kills
    end
  end

  # A reaped pid can name another process on Windows by now.
  def test_signal_app_child_leaves_a_reaped_app_alone_on_windows
    with_host_os("mingw32") do
      runner = DummyRunner.new
      commands = record_system(runner, result: true)
      assert_raises(Errno::ESRCH) { runner.send(:signal_app_child, "TERM", { child_pid: 4242, reaped_pid: 4242 }) }
      assert_empty commands
    end
  end

  def test_a_desktop_client_that_has_exited_is_left_alone_on_windows
    with_host_os("mingw32") do
      runner = DummyRunner.new
      commands = record_system(runner, result: true)
      pid = Process.spawn(RbConfig.ruby, "-e", "exit 0")
      runner.send(:detach_launched_process, pid).join

      runner.send(:stop_launched_process_on_windows, pid)

      assert_empty commands
    end
  end

  # `ruflet run --desktop` on a Windows Ruby, end to end: Process.spawn and
  # Process.kill behave as CRuby's win32 build does (no :pgroup option, no
  # signal to a negative pid, only KILL/INT/0 to another process). Ctrl-C
  # ends the app's process tree; on the way out the desktop client is ended
  # too, and the reaped app is not touched again.
  WINDOWS_APP = <<~RUBY
    require "socket"
    server = TCPServer.new("127.0.0.1", Integer(ENV.fetch("RUFLET_PORT")))
    probe = server.accept # the boot probe
    probe.readpartial(1024) rescue nil
    probe.close
    sleep 60
  RUBY

  def test_run_starts_and_stops_on_windows_ruby
    in_project do
      File.write("main.rb", "")
      port = free_port
      runner = scripted_runner(port: port, app: WINDOWS_APP)
      runner.define_singleton_method(:detect_desktop_client_command) do |url, root: nil|
        [RbConfig.ruby, "-e", "sleep 60", url]
      end
      commands = []
      runner.define_singleton_method(:system) do |*args, **_options|
        commands << args
        Process.kill("KILL", Integer(args.last)) if args.first == "taskkill"
        true
      end

      spawned = []
      kills = []
      traps = []
      real_spawn = Process.method(:spawn)
      real_kill = Process.method(:kill)
      real_trap = Signal.method(:trap)
      windows_spawn = lambda do |*args, **options|
        raise ArgumentError, "wrong exec option symbol: pgroup" if options.key?(:pgroup)

        spawned << options
        real_spawn.call(*args, **options.reject { |key, _| key == :new_pgroup })
      end
      windows_kill = lambda do |signal, *pids|
        kills << [signal, *pids]
        other = pids.any? { |pid| pid != Process.pid }
        raise Errno::EINVAL, "kill #{signal} #{pids.inspect}" if pids.any?(&:negative?)
        raise Errno::EINVAL, "kill #{signal} #{pids.inspect}" if other && !["KILL", "INT", 0, 9].include?(signal)

        real_kill.call(signal, *pids)
      end
      recording_trap = lambda do |signal, *rest, &handler|
        traps << signal if handler
        real_trap.call(signal, *rest, &handler)
      end

      code = nil
      out, err = capture_io do
        with_host_os("mingw32") do
          Process.stub(:spawn, windows_spawn) do
            Process.stub(:kill, windows_kill) do
              Signal.stub(:trap, recording_trap) do
                # Ctrl-C, once `ruflet run` has trapped it.
                interrupter = Thread.new do
                  sleep 0.01 until traps.include?("INT")
                  Process.kill("INT", Process.pid)
                end
                Timeout.timeout(60) { code = runner.command_run(["main.rb", "--desktop", "--no-reload"]) }
                interrupter.join
              end
            end
          end
        end
      end

      assert_equal 1, code, out + err
      app_options, client_options = spawned
      assert_equal true, app_options[:new_pgroup]
      refute client_options.key?(:pgroup)
      app_pid, client_pid = runner.calls.fetch(:spawned_pids)
      assert_equal [["taskkill", "/T", "/F", "/PID", app_pid.to_s], ["taskkill", "/T", "/F", "/PID", client_pid.to_s]],
                   commands, "Ctrl-C ends the app; leaving ends the desktop client, and nothing is ended twice"
      assert kills.none? { |_signal, *pids| pids.any?(&:negative?) }, kills.inspect
      refute_includes err, "Errno::EINVAL"
    end
  end

  # --- the app exits before its server is up --------------------------------

  def test_wait_for_server_boot_stops_as_soon_as_the_app_exits
    runner = DummyRunner.new
    pid = Process.spawn(RbConfig.ruby, "-e", "exit 3", pgroup: true)
    run_state = { child_pid: pid, restart: false }

    booted = :unset
    _out, err = capture_io { booted = runner.send(:wait_for_server_boot, free_port, run_state, timeout_seconds: 30) }

    assert_equal false, booted
    assert_equal 3, run_state[:boot_exit_status].exitstatus
    assert_equal pid, run_state[:reaped_pid]
    assert_includes err, "The app exited during startup (status 3); see the error above."
    refute_includes err, "did not become reachable"
    assert_raises(Errno::ECHILD) { Process.waitpid(pid, Process::WNOHANG) }
  end

  # ruflet_rails' desktop launcher calls it with the port alone.
  def test_wait_for_server_boot_with_the_port_alone_still_waits_and_warns
    port = free_port
    booted = :unset
    _out, err = capture_io do
      booted = DummyRunner.new.send(:wait_for_server_boot, port, timeout_seconds: 0.3)
    end

    assert booted
    assert_includes err, "Server did not become reachable at http://localhost:#{port} yet."
  end

  def test_wait_for_server_boot_returns_once_the_server_answers
    server = TCPServer.new("127.0.0.1", 0)
    acceptor = Thread.new { server.accept.close }
    pid = Process.spawn(RbConfig.ruby, "-e", "sleep 30", pgroup: true)
    run_state = { child_pid: pid, restart: false }

    booted = :unset
    _out, err = capture_io { booted = DummyRunner.new.send(:wait_for_server_boot, server.addr[1], run_state) }

    assert_equal true, booted
    assert_empty err
    refute run_state.key?(:boot_exit_status)
    assert_nil Process.waitpid(pid, Process::WNOHANG), "a running app is not reaped"
  ensure
    acceptor&.join(5)
    server&.close
    if pid
      Process.kill("KILL", pid)
      Process.wait(pid)
    end
  end

  # A listener that goes away during the probe (an app that "R" stops or
  # that crashes just as its server comes up), and macOS refusing a probe
  # that got the target port as its own port (EINVAL), mean "not up yet".
  def test_wait_for_server_boot_retries_a_probe_that_is_cut_off
    server = TCPServer.new("127.0.0.1", 0)
    acceptor = Thread.new { loop { server.accept.close } }
    pid = Process.spawn(RbConfig.ruby, "-e", "sleep 30", pgroup: true)
    real_new = TCPSocket.method(:new)
    [Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE, Errno::EINVAL].each do |error|
      run_state = { child_pid: pid, restart: false }
      attempts = 0
      cut_off_once = lambda do |*args|
        attempts += 1
        raise error if attempts == 1

        real_new.call(*args)
      end

      booted = :unset
      _out, err = capture_io do
        TCPSocket.stub(:new, cut_off_once) do
          booted = DummyRunner.new.send(:wait_for_server_boot, server.addr[1], run_state, timeout_seconds: 30)
        end
      end

      assert_equal true, booted, error.name
      assert_equal 2, attempts, error.name
      assert_empty err, error.name
      refute run_state.key?(:boot_exit_status), error.name
    end
    assert_nil Process.waitpid(pid, Process::WNOHANG), "a running app is not reaped"
  ensure
    acceptor&.kill
    server&.close
    if pid
      Process.kill("KILL", pid)
      Process.wait(pid)
    end
  end

  def test_a_probe_cut_off_by_an_app_that_exited_ends_the_wait
    port = free_port # outside the stub: TCPServer.new can resolve to TCPSocket.new
    pid = Process.spawn(RbConfig.ruby, "-e", "exit 3", pgroup: true)
    run_state = { child_pid: pid, restart: false }

    booted = :unset
    _out, err = capture_io do
      TCPSocket.stub(:new, ->(*) { raise Errno::ECONNRESET }) do
        booted = DummyRunner.new.send(:wait_for_server_boot, port, run_state, timeout_seconds: 30)
      end
    end

    assert_equal false, booted
    assert_equal 3, run_state[:boot_exit_status].exitstatus
    assert_includes err, "The app exited during startup (status 3); see the error above."
  end

  # On macOS a process group whose only member is the exited app, not reaped
  # yet, refuses a signal with EPERM. Stopping the app on the way out of an
  # error must not raise that in place of the error.
  def test_stopping_an_exited_app_on_the_way_out_does_not_hide_the_error
    in_project do
      File.write("main.rb", "")
      runner = scripted_runner(port: free_port, app: "exit 0")
      runner.define_singleton_method(:launch_target_client) { |*| raise IOError, "client launch failed" }
      group_signals = []
      real_kill = Process.method(:kill)
      zombie_only_group = lambda do |signal, *pids|
        return real_kill.call(signal, *pids) unless pids.any?(&:negative?)

        group_signals << [signal, *pids]
        raise Errno::EPERM
      end

      error = nil
      capture_io do
        Process.stub(:kill, zombie_only_group) do
          error = assert_raises(IOError) { runner.command_run(["main.rb", "--no-reload"]) }
        end
      end

      assert_equal "client launch failed", error.message
      app_pid = runner.calls.fetch(:spawned_pids).fetch(0)
      assert_equal [["TERM", -app_pid]], group_signals
    ensure
      Array(runner&.calls&.fetch(:spawned_pids)).each do |pid|
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end
    end
  end

  FAILING_APP = <<~RUBY
    warn "main.rb:3: syntax error found (SyntaxError)"
    exit 1
  RUBY

  def test_run_reports_an_app_that_fails_at_startup_and_launches_no_client
    in_project do
      File.write("main.rb", "")
      runner = scripted_runner(port: free_port, app: FAILING_APP)
      launched = []
      runner.define_singleton_method(:launch_desktop_client) { |url, **| launched << url; [] }

      code = nil
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      _out, err = capture_io { code = runner.command_run(["main.rb", "--desktop"]) }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      assert_equal 1, code
      assert_includes err, "The app exited during startup (status 1); see the error above."
      refute_includes err, "did not become reachable"
      assert_empty launched, "no client is opened for an app that is not running"
      assert_operator elapsed, :<, 10, "the run ends when the app does, not after the 10 s boot wait"
    end
  end

  # "R" restarts into code that no longer loads: the session ends with the
  # app's status, without a 10 s wait or a "Restarted" line.
  RESTART_APP = <<~RUBY
    require "socket"
    counter = ENV.fetch("TEST_START_COUNTER")
    starts = File.exist?(counter) ? File.read(counter).to_i : 0
    File.write(counter, (starts + 1).to_s)
    if starts.zero?
      server = TCPServer.new("127.0.0.1", Integer(ENV.fetch("RUFLET_PORT")))
      loop do
        client = server.accept
        client.readpartial(1024) rescue nil
        client.close
      end
    else
      warn "main.rb:3: syntax error found (SyntaxError)"
      exit 2
    end
  RUBY

  def test_a_restart_into_an_app_that_fails_at_startup_ends_the_session
    in_project do |dir|
      File.write("main.rb", "")
      port = free_port
      runner = scripted_runner(port: port, app: RESTART_APP, env: { "TEST_START_COUNTER" => File.join(dir, "starts") })
      press_big_r_once_up(runner)

      code = nil
      out, err = capture_io { Timeout.timeout(60) { code = runner.command_run(["main.rb"]) } }

      assert_equal 2, code, out + err
      assert_includes out, "Restarting app..."
      assert_includes err, "The app exited during startup (status 2); see the error above."
      refute_includes out, "Restarted in"
      refute_includes err, "did not become reachable"
    end
  end

  # "R" pressed while the first app is still booting stops it on purpose: no
  # startup-failure report, the client still opens, and the respawn runs.
  SLOW_THEN_HEALTHY_APP = <<~RUBY
    require "socket"
    counter = ENV.fetch("TEST_START_COUNTER")
    starts = File.exist?(counter) ? File.read(counter).to_i : 0
    # Written whole (then renamed): "R" fires as soon as the file exists,
    # and a TERM between File.write's create and its write would leave it
    # empty, so the respawn would count as a first start and sleep too.
    File.write("\#{counter}.tmp", (starts + 1).to_s)
    File.rename("\#{counter}.tmp", counter)
    sleep 60 if starts.zero?
    server = TCPServer.new("127.0.0.1", Integer(ENV.fetch("RUFLET_PORT")))
    probe = server.accept # the boot probe; then the app ends
    probe.readpartial(1024) rescue nil
    probe.close
  RUBY

  def test_r_during_the_first_boot_restarts_without_a_failure_report
    in_project do |dir|
      File.write("main.rb", "")
      port = free_port
      counter = File.join(dir, "starts")
      runner = scripted_runner(port: port, app: SLOW_THEN_HEALTHY_APP, env: { "TEST_START_COUNTER" => counter })
      launched = []
      runner.define_singleton_method(:launch_desktop_client) { |url, **| launched << url; [] }
      # "R" once the first app runs its own code (it then sleeps, never up).
      runner.define_singleton_method(:start_reload_input_thread) do |run_state|
        Thread.new do
          sleep 0.01 until File.exist?(counter)
          send(:handle_reload_command, "R", run_state)
        end
      end

      code = nil
      out, err = capture_io { Timeout.timeout(60) { code = runner.command_run(["main.rb", "--desktop"]) } }

      assert_equal 0, code, out + err
      refute_includes err, "exited during startup"
      refute_includes err, "did not become reachable"
      assert_includes out, "Restarted in"
      assert_equal ["http://localhost:#{port}"], launched
    end
  end

  # --- choosing the port ------------------------------------------------------

  def test_a_port_held_on_127_0_0_1_counts_as_busy
    held = TCPServer.new("127.0.0.1", 0)
    port = held.addr[1]

    picked = DummyRunner.new.send(:find_available_port, port)

    refute_equal port, picked, "http://localhost:#{port} would reach the other server"
    TCPServer.new("127.0.0.1", picked).close
  ensure
    held&.close
  end

  def test_a_port_held_on_ipv6_loopback_counts_as_busy
    held = begin
      TCPServer.new("::1", 0)
    rescue SystemCallError, SocketError
      skip "no IPv6 loopback on this host"
    end
    port = held.addr[1]

    picked = DummyRunner.new.send(:find_available_port, port)

    refute_equal port, picked, "http://localhost:#{port} would reach the other server"
  ensure
    held&.close
  end

  def test_a_free_port_is_kept
    port = free_port
    assert_equal port, DummyRunner.new.send(:find_available_port, port)
  end

  # No IPv6 (EADDRNOTAVAIL, EAFNOSUPPORT) or any refusal other than "in use"
  # leaves the port as it was chosen before.
  def test_a_loopback_bind_refused_for_other_reasons_keeps_the_port
    port = free_port
    real_new = TCPServer.method(:new)
    [Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT, Errno::EACCES].each do |error|
      refusing = lambda do |host, probe_port|
        raise error if host == "::1"

        real_new.call(host, probe_port)
      end
      picked = TCPServer.stub(:new, refusing) { DummyRunner.new.send(:find_available_port, port) }
      assert_equal port, picked, error.name
    end
  end

  # ... and such a refusal does not count the port as taken: with the start
  # port busy, the next port is chosen (not the start port, which is what
  # is returned once every attempt has failed).
  def test_a_loopback_bind_refused_for_other_reasons_does_not_count_as_taken
    held = nil
    loop do
      held = TCPServer.new("0.0.0.0", 0)
      break if held.addr[1] < 65_000 # leaves room for the ports after it

      held.close
    end
    port = held.addr[1]
    real_new = TCPServer.method(:new)
    [Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT, Errno::EACCES].each do |error|
      refusing = lambda do |host, probe_port|
        raise error if host == "::1"

        real_new.call(host, probe_port)
      end
      picked = TCPServer.stub(:new, refusing) { DummyRunner.new.send(:find_available_port, port) }
      assert_operator picked, :>, port, error.name
    end
  ensure
    held&.close
  end

  private

  # Runs command_run up to a real app child, with everything around it
  # (template check, QR, banners' dependencies) kept out of the way. The
  # child runs `app` with `ruby -e`.
  class ScriptedRunner < DummyRunner
    attr_reader :calls

    def initialize(port:, app:, env:)
      super()
      @calls = { spawned_pids: [] }
      @port = port
      @app = app
      @env = env
    end

    def resolve_backend_port(_target, requested_port: 8550) = @port
    def apply_local_ruflet_dev_overrides(_env) = nil
    def print_mobile_qr_hint(port:) = nil
    def manual_reload_supported? = false

    def build_runtime_command(_script_path, gemfile_path:, env:, reload: false)
      env.merge!(@env)
      [RbConfig.ruby, "-e", @app]
    end

    # The app's own output (the failing apps' SyntaxError line) stays out
    # of the test log.
    def spawn_app_child(env, cmd, run_state, **spawn_options)
      super(env, cmd, run_state, err: File::NULL, **spawn_options).tap { |pid| @calls[:spawned_pids] << pid }
    end

    def detach_launched_process(pid)
      @calls[:spawned_pids] << pid
      super
    end
  end

  def scripted_runner(port:, app:, env: {})
    ScriptedRunner.new(port: port, app: app, env: env)
  end

  # Sends "R", as the key reader would, once the first app is up and its
  # client step is done. (R pressed during the boot probe has its own tests.)
  def press_big_r_once_up(runner)
    up = Queue.new
    runner.define_singleton_method(:launch_target_client) do |*args|
      super(*args).tap { up << true }
    end
    runner.define_singleton_method(:start_reload_input_thread) do |run_state|
      Thread.new do
        up.pop
        send(:handle_reload_command, "R", run_state)
      end
    end
  end

  def record_system(runner, result:)
    commands = []
    runner.define_singleton_method(:system) do |*args, **_options|
      commands << args
      result
    end
    commands
  end

  def with_host_os(host_os)
    previous = RbConfig::CONFIG["host_os"]
    RbConfig::CONFIG["host_os"] = host_os
    yield
  ensure
    RbConfig::CONFIG["host_os"] = previous
  end

  def free_port
    probe = TCPServer.new("127.0.0.1", 0)
    probe.addr[1]
  ensure
    probe&.close
  end

  def in_project
    previous_client_dir = ENV.delete("RUFLET_CLIENT_DIR")
    Dir.mktmpdir { |dir| Dir.chdir(dir) { yield File.realpath(dir) } }
  ensure
    ENV["RUFLET_CLIENT_DIR"] = previous_client_dir if previous_client_dir
  end
end
