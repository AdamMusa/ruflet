# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "timeout"
require "socket"

class RufletCliRunCommandTest < Minitest::Test
  class DummyRunner
    include Ruflet::CLI::RunCommand
  end

  def with_client_dir(dir)
    previous = ENV["RUFLET_CLIENT_DIR"]
    ENV["RUFLET_CLIENT_DIR"] = dir
    yield
  ensure
    ENV["RUFLET_CLIENT_DIR"] = previous
  end

  def build_macos_app(products_dir, app_name)
    macos_dir = File.join(products_dir, "#{app_name}.app", "Contents", "MacOS")
    FileUtils.mkdir_p(macos_dir)
    executable = File.join(macos_dir, app_name)
    File.write(executable, "#!/bin/sh\n")
    FileUtils.chmod(0o755, executable)
    executable
  end

  def test_detect_desktop_client_finds_a_ruflet_app_client_by_its_own_name
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      products = File.join(dir, "build", "client", "build", "macos", "Build", "Products", "Release")
      expected = build_macos_app(products, "Ruflet Explorer")

      command = with_client_dir(dir) do
        DummyRunner.new.send(:detect_desktop_client_command, "http://127.0.0.1:8550")
      end

      assert_equal [expected, "http://127.0.0.1:8550"], command
    end
  end

  def test_detect_desktop_client_still_finds_a_bare_flutter_client
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      products = File.join(dir, "build", "macos", "Build", "Products", "Release")
      expected = build_macos_app(products, "ruflet_client")

      command = with_client_dir(dir) do
        DummyRunner.new.send(:detect_desktop_client_command, "http://127.0.0.1:8550")
      end

      assert_equal [expected, "http://127.0.0.1:8550"], command
    end
  end

  def test_detect_desktop_client_finds_a_prebuilt_bundle_of_any_name
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      expected = build_macos_app(File.join(dir, "desktop"), "Ruflet Explorer")

      command = with_client_dir(dir) do
        DummyRunner.new.send(:detect_desktop_client_command, "http://127.0.0.1:8550")
      end

      assert_equal [expected, "http://127.0.0.1:8550"], command
    end
  end

  def test_prebuilt_desktop_present_accepts_a_bundle_named_after_the_project
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      build_macos_app(File.join(dir, "desktop"), "Ruflet Explorer")

      assert DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "macos")
    end
  end

  def test_prebuilt_desktop_present_rejects_a_bundle_without_an_executable
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "desktop", "Ruflet Explorer.app", "Contents", "MacOS"))

      refute DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "macos")
    end
  end

  def test_prebuilt_desktop_present_accepts_linux_and_windows_binaries_of_any_name
    Dir.mktmpdir do |dir|
      desktop = File.join(dir, "desktop")
      FileUtils.mkdir_p(File.join(desktop, "lib"))
      binary = File.join(desktop, "rufletexplorer")
      File.write(binary, "#!/bin/sh\n")
      FileUtils.chmod(0o755, binary)

      assert DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "linux")
    end

    Dir.mktmpdir do |dir|
      desktop = File.join(dir, "desktop")
      FileUtils.mkdir_p(desktop)
      File.write(File.join(desktop, "rufletexplorer.exe"), "MZ")

      assert DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "windows")
    end
  end

  def test_prebuilt_assets_present_rejects_a_web_cache_without_a_compiled_entrypoint
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")

      refute DummyRunner.new.send(:prebuilt_assets_present?, dir, web: true, desktop: false)

      File.write(File.join(dir, "web", "flutter_bootstrap.js"), "// built")

      assert DummyRunner.new.send(:prebuilt_assets_present?, dir, web: true, desktop: false)
    end
  end

  # A cache that passes the presence check short circuits the download, so a
  # check looser than what `run --web` accepts would strand the user on a
  # broken cache that never repairs itself.
  def test_incomplete_web_cache_is_redownloaded_instead_of_being_accepted
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")

      release = {
        "tag_name" => "prebuild-main",
        "published_at" => "2026-07-15T12:00:00Z",
        "assets" => [
          {
            "name" => "ruflet_client-web.tar.gz",
            "browser_download_url" => "https://example.test/web.tar.gz"
          }
        ]
      }
      downloads = 0
      runner.define_singleton_method(:ruflet_version) { "0.0.20" }
      runner.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      runner.define_singleton_method(:fetch_release_for_version) { |wanted_assets:| release }
      runner.define_singleton_method(:download_file) do |_url, destination, limit: 5|
        downloads += 1
        File.write(destination, "archive")
      end
      runner.define_singleton_method(:extract_archive) do |_archive, destination|
        FileUtils.mkdir_p(destination)
        File.write(File.join(destination, "index.html"), "<html></html>")
        File.write(File.join(destination, "flutter_bootstrap.js"), "// built")
        true
      end

      root = runner.send(:ensure_prebuilt_client, web: true, platform: "macos")

      assert_equal dir, root
      assert_equal 1, downloads
      assert File.file?(File.join(dir, "web", "flutter_bootstrap.js"))
    end
  end

  def test_prebuilt_desktop_present_is_false_without_a_desktop_directory
    Dir.mktmpdir do |dir|
      refute DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "macos")
      refute DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "linux")
      refute DummyRunner.new.send(:prebuilt_desktop_present?, dir, platform: "windows")
    end
  end

  def build_web_output(dir)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "index.html"), "<html></html>")
    File.write(File.join(dir, "flutter_bootstrap.js"), "// built")
    dir
  end

  def test_detect_web_client_dir_prefers_the_ruflet_app_build
    Dir.mktmpdir do |dir|
      web_dir = build_web_output(File.join(dir, "build", "client", "build", "web"))

      found = with_client_dir(dir) { DummyRunner.new.send(:detect_web_client_dir) }
      assert_equal web_dir, found
    end
  end

  def test_detect_web_client_dir_still_finds_a_bare_flutter_web_build
    Dir.mktmpdir do |dir|
      web_dir = build_web_output(File.join(dir, "build", "web"))

      found = with_client_dir(dir) { DummyRunner.new.send(:detect_web_client_dir) }
      assert_equal web_dir, found
    end
  end

  def test_detect_web_client_dir_ignores_an_unbuilt_projects_web_sources
    Dir.mktmpdir do |dir|
      # A Flutter project ships web/index.html as a source template; serving it
      # would hand the browser a page with no application in it.
      sources = File.join(dir, "build", "client", "web")
      FileUtils.mkdir_p(sources)
      File.write(File.join(sources, "index.html"), "<html></html>")

      found = with_client_dir(dir) { DummyRunner.new.send(:detect_web_client_dir) }
      assert_nil found
    end
  end

  def test_find_nearest_gemfile_walks_up_directories
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      nested = File.join(root, "examples", "ruflet_studio")
      FileUtils.mkdir_p(nested)
      gemfile = File.join(root, "Gemfile")
      File.write(gemfile, "source \"https://rubygems.org\"\n")

      found = DummyRunner.new.send(:find_nearest_gemfile, nested)
      assert_equal gemfile, found
    end
  end

  def test_find_nearest_gemfile_returns_nil_without_gemfile
    Dir.mktmpdir do |dir|
      nested = File.join(dir, "a", "b")
      FileUtils.mkdir_p(nested)
      found = DummyRunner.new.send(:find_nearest_gemfile, nested)
      assert_nil found
    end
  end

  def test_release_asset_matches_supports_fallback_names
    runner = DummyRunner.new

    assert runner.send(:release_asset_matches?, "ruflet_client-web-build.tar.gz", :web, nil)
    assert runner.send(:release_asset_matches?, "ruflet_client-macos-arm64.zip", :desktop, "macos")
    assert runner.send(:release_asset_matches?, "ruflet_client-linux-amd64.tgz", :desktop, "linux")
    assert runner.send(:release_asset_matches?, "ruflet_client-windows-latest.zip", :desktop, "windows")

    refute runner.send(:release_asset_matches?, "other_project-web.tar.gz", :web, nil)
    refute runner.send(:release_asset_matches?, "ruflet_client-macos.tar.gz", :desktop, "macos")
  end

  def test_release_asset_matches_accepts_the_explorer_names
    runner = DummyRunner.new

    assert runner.send(:release_asset_matches?, "ruflet_explorer-web.tar.gz", :web, nil)
    assert runner.send(:release_asset_matches?, "ruflet_explorer-macos-universal.zip", :desktop, "macos")
    assert runner.send(:release_asset_matches?, "ruflet_explorer-linux-x64.tar.gz", :desktop, "linux")
    assert runner.send(:release_asset_matches?, "ruflet_explorer-windows-x64.zip", :desktop, "windows")
    # An older release still carries the retired experimental archive, which
    # must never be mistaken for the desktop client.
    refute runner.send(
      :release_asset_matches?,
      "ruflet_explorer-macos-experimental-universal.zip", :desktop, "macos"
    )

    refute runner.send(:release_asset_matches?, "some_other_explorer-web.tar.gz", :web, nil)
  end

  def test_wanted_asset_names_use_the_explorer_prefix
    runner = DummyRunner.new

    assert_equal "ruflet_explorer-macos-universal.zip", runner.send(:desktop_asset_name_for, "macos")
    assert_equal "ruflet_explorer-linux-x64.tar.gz", runner.send(:desktop_asset_name_for, "linux")
    assert_equal "ruflet_explorer-windows-x64.zip", runner.send(:desktop_asset_name_for, "windows")
  end

  # The manifest is uploaded last, so it is how a run is judged complete. A
  # release published before the rename still carries the old name.
  def test_rolling_release_complete_accepts_either_manifest_name
    runner = DummyRunner.new

    assert runner.send(:rolling_release_complete?, { "assets" => [{ "name" => "ruflet_explorer-manifest.json" }] })
    assert runner.send(:rolling_release_complete?, { "assets" => [{ "name" => "ruflet_client-manifest.json" }] })
    refute runner.send(:rolling_release_complete?, { "assets" => [{ "name" => "ruflet_explorer-web.tar.gz" }] })
  end

  def test_prebuilt_client_installs_from_renamed_release_assets
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      release = {
        "tag_name" => "prebuild-main",
        "assets" => [
          { "name" => "ruflet_explorer-manifest.json", "id" => 7, "updated_at" => "2026-07-29T00:00:00Z" },
          { "name" => "ruflet_explorer-web.tar.gz", "browser_download_url" => "https://example.test/web.tar.gz" }
        ]
      }
      runner.define_singleton_method(:ruflet_version) { "0.0.21" }
      runner.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      runner.define_singleton_method(:fetch_release_for_version) { |wanted_assets:| release }
      runner.define_singleton_method(:download_file) { |_url, destination, limit: 5| File.write(destination, "archive") }
      runner.define_singleton_method(:extract_archive) do |_archive, destination|
        FileUtils.mkdir_p(destination)
        File.write(File.join(destination, "index.html"), "<html></html>")
        File.write(File.join(destination, "flutter_bootstrap.js"), "// built")
        true
      end

      assert_equal dir, runner.send(:ensure_prebuilt_client, web: true, platform: "macos")
      assert File.file?(File.join(dir, "web", "flutter_bootstrap.js"))
    end
  end

  def test_build_runtime_command_without_gemfile_runs_script_directly
    runner = DummyRunner.new
    env = {}

    cmd = runner.send(:build_runtime_command, "/tmp/app.rb", gemfile_path: nil, env: env)

    assert_equal [RbConfig.ruby, "/tmp/app.rb"], cmd
  end

  def test_build_runtime_command_with_gemfile_uses_bundler_setup
    runner = DummyRunner.new
    Dir.mktmpdir do |dir|
      gemfile = File.join(dir, "Gemfile")
      File.write(gemfile, "source \"https://rubygems.org\"\n")
      env = {}
      runner.define_singleton_method(:system) { |_env, *_args| true }

      cmd = runner.send(:build_runtime_command, "/tmp/app.rb", gemfile_path: gemfile, env: env)
      assert_equal "ruby", File.basename(cmd[0])
      assert_equal "-rbundler/setup", cmd[1]
      assert_equal "/tmp/app.rb", cmd[2]
    end
  end

  def test_build_runtime_command_with_reload_wraps_script_in_harness
    runner = DummyRunner.new
    env = {}

    cmd = runner.send(:build_runtime_command, "/tmp/app.rb", gemfile_path: nil, env: env, reload: true)

    harness = File.expand_path("../lib/ruflet/hot_reload/harness.rb", __dir__)
    assert_equal [RbConfig.ruby, harness], cmd
    assert_equal "/tmp/app.rb", env["RUFLET_APP_SCRIPT"]
    assert_equal "/tmp", env["RUFLET_WATCH_ROOT"]
    assert File.file?(harness), "hot reload harness must ship with the CLI gem"
  end

  def test_build_runtime_command_with_reload_and_gemfile_keeps_bundler_setup
    runner = DummyRunner.new
    Dir.mktmpdir do |dir|
      gemfile = File.join(dir, "Gemfile")
      File.write(gemfile, "source \"https://rubygems.org\"\n")
      env = {}
      runner.define_singleton_method(:system) { |_env, *_args| true }

      cmd = runner.send(:build_runtime_command, "/tmp/app.rb", gemfile_path: gemfile, env: env, reload: true)

      assert_equal "-rbundler/setup", cmd[1]
      assert_equal runner.send(:hot_reload_harness_path), cmd[2]
      assert_equal "/tmp/app.rb", env["RUFLET_APP_SCRIPT"]
    end
  end

  # The app child and a grandchild in its process group each write one byte
  # once they run user code. Signalling earlier races Ruby's own boot: a Ruby
  # process that gets TERM while still loading (gem prelude, -r files) exits
  # with status 1 instead of dying by the signal, which is what made this
  # test flaky under load. Both processes inherit the pipe's write end, so
  # EOF on the read end proves the whole group is gone. (The sleeps only
  # bound a broken R; nothing waits on them.)
  RELOAD_CHILD_SCRIPT = <<~RUBY
    fork { $stdout.write("g"); $stdout.flush; sleep 120 }
    $stdout.write("c"); $stdout.flush
    sleep 120
  RUBY

  def test_handle_reload_command_big_r_requests_full_restart
    runner = DummyRunner.new
    reader, writer = IO.pipe
    child = Process.spawn(RbConfig.ruby, "-e", RELOAD_CHILD_SCRIPT, pgroup: true, out: writer)
    writer.close
    assert_equal 2, reader.read(2).to_s.bytesize, "child and grandchild must both be running"
    run_state = { child_pid: child, restart: false }

    assert runner.send(:handle_reload_command, "R", run_state)
    assert run_state[:restart], "R must flag a full restart before terminating the child"
    _pid, status = Process.wait2(child)
    reaped = true
    assert status.signaled?, "R must terminate the child by a signal"
    # Waits on EOF, not on time; the limit only stops a broken R from hanging.
    assert IO.select([reader], nil, nil, 60), "the grandchild outlived R"
    assert_nil reader.read(1), "R must terminate the child's whole process group"
    group_gone = true
  ensure
    reader&.close
    writer&.close unless writer&.closed?
    begin
      Process.kill("KILL", -child) if child && !group_gone
      Process.wait(child) if child && !reaped
    rescue Errno::ESRCH, Errno::EPERM, Errno::ECHILD
      # ESRCH: already gone. EPERM: the runner denies signalling the group.
      nil
    end
  end

  # "r" pressed while the app is still booting used to deliver USR1 before
  # the hot-reload harness had trapped it, so Ruby's default action killed
  # the app and ended the `ruflet run` session. The app here is the real
  # harness with an app script that blocks mid-boot on a FIFO the test holds,
  # so "r" lands in that window every time; FIFOs also carry the progress
  # back, so the test waits on events only.
  BOOT_GATED_APP = <<~RUBY
    gate = File.open(ENV.fetch("TEST_GATE_FIFO"), "r") unless $ruflet_test_loads
    $ruflet_test_progress ||= File.open(ENV.fetch("TEST_PROGRESS_FIFO"), "w")
    $ruflet_test_loads = ($ruflet_test_loads || 0) + 1
    $ruflet_test_progress.write("L\#{$ruflet_test_loads}")
    $ruflet_test_progress.flush
    if gate
      gate.read(1) # boot stays here until the test opens the gate
      gate.close
    end
    Ruflet.run(host: "127.0.0.1", port: 0) { |_page| }
  RUBY

  def test_reload_pressed_during_boot_is_applied_once_the_app_is_up
    skip "needs USR1 and FIFOs" unless Signal.list.key?("USR1") && File.respond_to?(:mkfifo)

    Dir.mktmpdir("ruflet-reload-boot-") do |dir|
      script = File.join(dir, "main.rb")
      File.write(script, BOOT_GATED_APP)
      gate_fifo = File.join(dir, "gate")
      progress_fifo = File.join(dir, "progress")
      File.mkfifo(gate_fifo)
      File.mkfifo(progress_fifo)

      runner = DummyRunner.new
      env = {
        "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
        "RUBYLIB" => runner.send(:local_ruflet_dev_lib_paths).join(File::PATH_SEPARATOR),
        "TEST_GATE_FIFO" => gate_fifo,
        "TEST_PROGRESS_FIFO" => progress_fifo
      }
      cmd = runner.send(:build_runtime_command, script, gemfile_path: nil, env: env, reload: true)
      env.delete("RUFLET_BOOTSNAP_DIR") # keep the test out of ~/.ruflet
      # The queue itself is under test, so no readiness fallback.
      run_state = runner.send(:new_run_state, track_ready: true, ready_fallback_seconds: nil)

      Timeout.timeout(120) do # guards a broken build only; nothing waits on time
        runner.send(:spawn_app_child, env, cmd, run_state, out: File::NULL, err: File::NULL)
        gate = File.open(gate_fifo, "w")         # the app is running user code
        progress = File.open(progress_fifo, "r")
        assert_equal "L1", progress.read(2), "the app must be mid-boot"

        out, = capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
        assert_match(/queued/i, out, "r during boot must be queued, not delivered")

        gate.write(".")
        gate.close
        assert_equal "L2", progress.read(2), "the queued reload must run once the app is up"
        assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG),
                   "the session's app must survive r pressed during boot"
      ensure
        progress&.close
        gate&.close unless gate.nil? || gate.closed?
      end
    ensure
      if run_state && run_state[:child_pid]
        begin
          Process.kill("KILL", -run_state[:child_pid])
          Process.wait(run_state[:child_pid])
        rescue Errno::ESRCH, Errno::ECHILD, Errno::EPERM
          nil
        end
      end
    end
  end

  # Records reload signals (and still sends them) so a test can prove which
  # child, if any, a reload was delivered to.
  class SignalSpyRunner < DummyRunner
    attr_reader :reload_signals, :delivered

    def initialize
      super
      @reload_signals = []
      @delivered = Queue.new # one entry per reload signal, once it was attempted
    end

    def send_reload_signal(pid)
      reload_signals << pid
      super
    ensure
      delivered << pid
    end
  end

  # One BOOT_GATED_APP child spawned the way `ruflet run` does, held mid-boot
  # until #release.
  class GatedApp
    attr_reader :progress

    def initialize(runner, run_state, env, cmd, dir)
      runner.send(:spawn_app_child, env, cmd, run_state, out: File::NULL, err: File::NULL)
      @pid = run_state[:child_pid]
      @gate = File.open(File.join(dir, "gate"), "w") # the app runs user code
      @progress = File.open(File.join(dir, "progress"), "r")
    end

    def release
      @gate.write(".")
      @gate.close
    end

    def close
      @gate.close unless @gate.closed?
      @progress.close
    end
  end

  # core_shim: source of a ruflet_core.rb loaded in place of this checkout's
  # (it can load the real one from TEST_REAL_CORE_LIB). files: more app
  # files, by name. bootsnap: set bootsnap up as `ruflet run` does, with its
  # cache in the test's directory. The queue is under test unless
  # ready_fallback_seconds is given.
  def with_gated_app_session(runner, app: BOOT_GATED_APP, core_shim: nil, ready_fallback_seconds: nil, files: {}, bootsnap: false)
    skip "needs USR1 and FIFOs" unless Signal.list.key?("USR1") && File.respond_to?(:mkfifo)

    Dir.mktmpdir("ruflet-reload-restart-") do |dir|
      script = File.join(dir, "main.rb")
      File.write(script, app)
      files.each { |name, source| File.write(File.join(dir, name), source) }
      %w[gate progress core_gate].each { |name| File.mkfifo(File.join(dir, name)) }
      lib_paths = runner.send(:local_ruflet_dev_lib_paths)
      if core_shim
        shim_dir = File.join(dir, "core_shim")
        FileUtils.mkdir_p(shim_dir)
        File.write(File.join(shim_dir, "ruflet_core.rb"), core_shim)
        lib_paths = [shim_dir] + lib_paths
      end
      env = {
        "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
        "RUBYLIB" => lib_paths.join(File::PATH_SEPARATOR),
        "TEST_REAL_CORE_LIB" => runner.send(:local_ruflet_dev_lib_paths).first,
        "TEST_GATE_FIFO" => File.join(dir, "gate"),
        "TEST_PROGRESS_FIFO" => File.join(dir, "progress"),
        "TEST_CORE_GATE_FIFO" => File.join(dir, "core_gate")
      }
      cmd = runner.send(:build_runtime_command, script, gemfile_path: nil, env: env, reload: true)
      env.delete("RUFLET_BOOTSNAP_DIR") # keep the test out of ~/.ruflet
      env["RUFLET_BOOTSNAP_DIR"] = File.join(dir, "bootsnap") if bootsnap
      run_state = runner.send(:new_run_state, track_ready: true, ready_fallback_seconds: ready_fallback_seconds)
      spawned = []
      begin
        Timeout.timeout(120) do # guards a broken build only; nothing waits on time
          yield run_state, -> { GatedApp.new(runner, run_state, env, cmd, dir).tap { |app| spawned << app } }, env, cmd, dir
        end
      ensure
        spawned.each(&:close)
        if run_state[:child_pid]
          begin
            Process.kill("KILL", -run_state[:child_pid])
            Process.wait(run_state[:child_pid])
          rescue Errno::ESRCH, Errno::ECHILD, Errno::EPERM
            nil
          end
        end
      end
    end
  end

  # What the run loop does after "R": reap the old app, respawn.
  def restart_app(run_state, spawn_app)
    Process.wait(run_state[:child_pid])
    run_state[:restart] = false
    spawn_app.call
  end

  def test_restart_drops_a_reload_queued_during_boot
    runner = SignalSpyRunner.new
    with_gated_app_session(runner) do |run_state, spawn_app|
      first = spawn_app.call
      assert_equal "L1", first.progress.read(2)
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert run_state[:reload_pending], "r during boot is queued"

      capture_io { assert runner.send(:handle_reload_command, "R", run_state) }
      second = restart_app(run_state, spawn_app)
      refute run_state[:reload_pending], "the restarted app loads the current code"
      assert_equal "L1", second.progress.read(2)
      second.release
      run_state[:ready_thread].join # the CLI has seen the new app's ready byte

      assert run_state[:ready]
      assert_empty runner.reload_signals, "the stale reload must not reach the new app"
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_equal [run_state[:child_pid]], runner.reload_signals
      assert_equal "L2", second.progress.read(2), "a fresh r still reloads the restarted app"
    end
  end

  # Pre-existing: once the app had reported ready, "r" between "R" and the
  # respawn signalled the reaped app, got ESRCH and stopped the key reader,
  # so no further key worked for the rest of the session.
  def test_r_between_restart_and_respawn_keeps_the_key_reader_alive
    runner = SignalSpyRunner.new
    with_gated_app_session(runner) do |run_state, spawn_app|
      first = spawn_app.call
      assert_equal "L1", first.progress.read(2)
      first.release
      run_state[:ready_thread].join
      assert run_state[:ready]

      capture_io { assert runner.send(:handle_reload_command, "R", run_state) }
      refute run_state[:ready], "R marks the app not ready until the respawn reports"
      Process.wait(run_state[:child_pid]) # the old app is gone, no respawn yet
      out, = capture_io do
        assert runner.send(:handle_reload_command, "r", run_state),
               "r during a restart must not end the key reader"
      end
      assert_match(/restart/i, out)
      assert_empty runner.reload_signals, "nothing may be signalled while no app is up"

      run_state[:restart] = false
      second = spawn_app.call
      assert_equal "L1", second.progress.read(2)
      second.release
      run_state[:ready_thread].join
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_equal "L2", second.progress.read(2), "r works again once the app is back"
    end
  end

  # The same boot gate, for an app started with the DSL: `Ruflet.app { }.run`
  # calls Ruflet::Server#start itself and never goes through Ruflet.run.
  DSL_GATED_APP = BOOT_GATED_APP.sub(/^Ruflet\.run\(.*\n/, <<~RUBY)
    require "ruflet_server"
    Ruflet.app(host: "127.0.0.1", port: 0) { text("hi") }.run
  RUBY

  # A ruflet_core from before Ruflet.with_run_interceptor: Ruflet.run builds
  # and starts the server itself, so nothing can intercept it.
  CORE_WITHOUT_RUN_INTERCEPTORS = <<~RUBY
    require File.join(ENV.fetch("TEST_REAL_CORE_LIB"), "ruflet_core")
    Ruflet.singleton_class.send(:remove_method, :with_run_interceptor)
    module Ruflet
      def self.run(entrypoint = nil, host: "0.0.0.0", port: 8550, &block)
        callback = entrypoint || block
        require "ruflet_server"
        Server.new(host: host, port: port) { |page| callback.call(page) }.start
      end
    end
  RUBY

  # Holds the hot-reload harness before it has trapped USR1 (it requires
  # ruflet_core first), until the test writes to the core gate.
  CORE_GATED_BEFORE_THE_HARNESS = <<~RUBY
    File.open(ENV.fetch("TEST_CORE_GATE_FIFO"), "r") { |gate| gate.read(1) }
    require File.join(ENV.fetch("TEST_REAL_CORE_LIB"), "ruflet_core")
  RUBY

  def test_reload_pressed_during_boot_reaches_an_app_started_with_the_dsl
    runner = SignalSpyRunner.new
    with_gated_app_session(runner, app: DSL_GATED_APP) do |run_state, spawn_app|
      app = spawn_app.call
      assert_equal "L1", app.progress.read(2), "the app must be mid-boot"
      out, = capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_match(/queued/i, out)

      app.release
      assert_equal "L2", app.progress.read(2), "a DSL app must report ready, then take the queued reload"
      assert_equal [run_state[:child_pid]], runner.reload_signals
      assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG)
    end
  end

  def test_reload_pressed_during_boot_reaches_an_app_on_a_ruflet_core_without_run_interceptors
    runner = SignalSpyRunner.new
    with_gated_app_session(runner, core_shim: CORE_WITHOUT_RUN_INTERCEPTORS) do |run_state, spawn_app|
      app = spawn_app.call
      assert_equal "L1", app.progress.read(2), "the app must be mid-boot"
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert run_state[:reload_pending]

      app.release
      assert_equal "L2", app.progress.read(2), "the queued reload must run on an older ruflet_core too"
      assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG)
    end
  end

  # If an app that has trapped USR1 never reports ready, "r" must not stay
  # queued forever: after the fallback it is delivered as before the queue
  # existed. "r" here is pressed before the harness has trapped USR1, which
  # the fallback must wait for (USR1 then would kill the app); it is then
  # delivered while the app is still mid-boot, which the trap must survive.
  def test_without_a_ready_report_a_queued_reload_is_sent_once_the_app_has_trapped_it
    runner = SignalSpyRunner.new
    with_gated_app_session(runner, core_shim: CORE_GATED_BEFORE_THE_HARNESS, ready_fallback_seconds: 0) do |run_state, _spawn_app, env, cmd, dir|
      runner.send(:spawn_app_child, env, cmd, run_state, out: File::NULL, err: File::NULL)
      core_gate = File.open(File.join(dir, "core_gate"), "w") # the harness is loading ruflet_core
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert run_state[:reload_pending], "r before the app traps USR1 must be queued"

      core_gate.write(".")
      core_gate.close
      assert_equal run_state[:child_pid], next_from(runner.delivered, "the fallback"), "the queued reload is sent without a ready report"
      assert_equal [run_state[:child_pid]], runner.reload_signals
      refute run_state[:reload_pending]

      gate = File.open(File.join(dir, "gate"), "w") # the app is still mid-boot
      progress = File.open(File.join(dir, "progress"), "r")
      assert_equal "L1", progress.read(2)
      gate.write(".")
      gate.close
      assert_equal "L2", progress.read(2), "the reload delivered during boot runs once the app is up"
      assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG)
    ensure
      [core_gate, gate, progress].each { |io| io.close if io && !io.closed? }
    end
  end

  # An app that serves from a thread of its own while its main script goes
  # on, like `Thread.new { server.start }; loop { sleep 1 }`. Nothing in it is
  # the runner's to capture, so it serves exactly as without the runner and
  # never reports ready. On v0.0.23 "r" killed it; it must stay up, and "r"
  # reaches only the USR1 trap the harness reported.
  THREAD_SERVER_APP = <<~RUBY
    gate = File.open(ENV.fetch("TEST_GATE_FIFO"), "r")
    progress = File.open(ENV.fetch("TEST_PROGRESS_FIFO"), "w")
    require "ruflet"
    require "ruflet_server"
    server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| }
    Thread.new { server.start }
    sleep 0.01 until server.port.to_i.positive?
    progress.puts(server.port)
    progress.flush
    gate.read(1) # the script goes on with its own work
    progress.puts("still running")
    progress.flush
    sleep
  RUBY

  def test_an_app_serving_from_its_own_thread_stays_served_and_survives_r
    runner = SignalSpyRunner.new
    with_gated_app_session(runner, app: THREAD_SERVER_APP, ready_fallback_seconds: 0) do |run_state, spawn_app|
      app = spawn_app.call
      port = Integer(app.progress.gets)
      TCPSocket.new("127.0.0.1", port).close # the app's own thread serves it

      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_equal run_state[:child_pid], next_from(runner.delivered, "the fallback"), "r reaches the app once its trap is reported"
      app.release
      assert_equal "still running\n", app.progress.gets, "USR1 is trapped, so r cannot kill the app"
      TCPSocket.new("127.0.0.1", port).close
      assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG)
    end
  end

  # main.rb requires app.rb, which starts the app with `Ruflet.app { }.run`.
  # The app reported ready and "r" was sent, but the reload it started
  # waited forever on app.rb's require (the app's own server serves from
  # inside it), so neither "r" nor a save ever reloaded. Each load reports
  # its count and whether its top-level frame reads "<main>" (bootsnap's
  # compile cache) or "<top (required)>".
  REQUIRED_DSL_MAIN = <<~RUBY
    require "ruflet"
    require "ruflet_server"
    require_relative "app"
  RUBY
  REQUIRED_APP_PROGRESS = <<~RUBY
    $ruflet_test_progress ||= File.open(ENV.fetch("TEST_PROGRESS_FIFO"), "w")
    $ruflet_test_loads = ($ruflet_test_loads || 0) + 1
    compiled = caller_locations(0, 1).first.label == "<main>" ? "m" : "t"
    $ruflet_test_progress.write("L\#{$ruflet_test_loads}\#{compiled}")
    $ruflet_test_progress.flush
  RUBY
  REQUIRED_DSL_APP = <<~RUBY
    #{REQUIRED_APP_PROGRESS.chomp}
    Ruflet.app(host: "127.0.0.1", port: 0) { text("hi") }.run
  RUBY

  # The same layout with Ruflet.run in app.rb. That reloaded on v0.0.23 (the
  # run interceptor returns at once, so app.rb's require completes) and
  # still does.
  REQUIRED_RUN_MAIN = <<~RUBY
    require "ruflet"
    require_relative "app"
  RUBY
  REQUIRED_RUN_APP = <<~RUBY
    #{REQUIRED_APP_PROGRESS.chomp}
    Ruflet.run(host: "127.0.0.1", port: 0) { |_page| nil }
  RUBY

  def test_r_and_a_save_reload_an_app_started_in_a_file_the_script_requires
    assert_required_app_reloads(main: REQUIRED_DSL_MAIN, app: REQUIRED_DSL_APP, bootsnap: false, frame: "t")
  end

  # `ruflet run` sets bootsnap up whenever it is installed.
  def test_r_and_a_save_reload_an_app_started_in_a_required_file_under_bootsnap
    skip "bootsnap is not installed" if Gem::Specification.find_all_by_name("bootsnap").empty?

    assert_required_app_reloads(main: REQUIRED_DSL_MAIN, app: REQUIRED_DSL_APP, bootsnap: true, frame: "m")
  end

  def test_r_and_a_save_reload_a_ruflet_run_app_in_a_file_the_script_requires
    assert_required_app_reloads(main: REQUIRED_RUN_MAIN, app: REQUIRED_RUN_APP, bootsnap: false, frame: "t")
  end

  def assert_required_app_reloads(main:, app:, bootsnap:, frame:)
    runner = SignalSpyRunner.new
    with_gated_app_session(runner, app: main, files: { "app.rb" => app }, bootsnap: bootsnap) do |run_state, _spawn_app, env, cmd, dir|
      runner.send(:spawn_app_child, env, cmd, run_state, out: File::NULL, err: File::NULL)
      progress = File.open(File.join(dir, "progress"), "r")
      assert_equal "L1#{frame}", read_progress(progress)
      # The app reports ready and closes the fd; the limit only turns an app
      # that never does into a failure instead of the session guard's timeout.
      assert run_state[:ready_thread].join(30), "the app never reported ready"
      assert run_state[:ready], "the app must report ready"

      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_equal [run_state[:child_pid]], runner.reload_signals, "r is sent at once"
      assert_equal "L2#{frame}", read_progress(progress), "r must reload the app"

      File.write(File.join(dir, "app.rb"), "#{app}# saved\n")
      assert_equal "L3#{frame}", read_progress(progress), "a save must reload it too"
      capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
      assert_equal "L4#{frame}", read_progress(progress), "and r keeps working"
      assert_nil Process.waitpid(run_state[:child_pid], Process::WNOHANG)
    ensure
      progress&.close
    end
  end

  # The next 3-byte progress report; the limit only stops a hung reload from
  # hanging the suite.
  def read_progress(io)
    assert IO.select([io], nil, nil, 30), "the app never reported"
    io.read(3)
  end

  # The next entry of queue. The fallback these tests wait for fires at once
  # (ready_fallback_seconds: 0); the limit only turns a fallback that never
  # fires into a failure instead of a hung suite.
  def next_from(queue, what, seconds: 15)
    Timeout.timeout(seconds) { queue.pop }
  rescue Timeout::Error
    flunk "#{what} never fired"
  end

  # Records reload signals without sending them (these pids are not real),
  # and each time the readiness watcher decides the app is up.
  class SignalRecorder < DummyRunner
    attr_reader :reload_signals, :marked_ready

    def initialize
      super
      @reload_signals = []
      @marked_ready = Queue.new
    end

    def send_reload_signal(pid)
      reload_signals << pid
    end

    def mark_child_ready(pid, run_state)
      super
    ensure
      marked_ready << pid
    end
  end

  def watch_ready_pipe(runner, child_pid:, watched_pid: child_pid, ready_fallback_seconds:)
    run_state = runner.send(:new_run_state, track_ready: true, ready_fallback_seconds: ready_fallback_seconds)
    run_state[:child_pid] = child_pid
    capture_io { assert runner.send(:handle_reload_command, "r", run_state) }
    assert run_state[:reload_pending], "r before the app reports must be queued"
    reader, writer = IO.pipe
    thread = runner.send(:watch_child_ready, reader, watched_pid, run_state)
    Timeout.timeout(60) { yield run_state, writer, thread } # guards a broken watcher only
  ensure
    writer&.close unless writer.nil? || writer.closed?
  end

  def test_ready_fallback_sends_a_queued_reload_to_an_app_that_trapped_it
    runner = SignalRecorder.new
    watch_ready_pipe(runner, child_pid: 4242, ready_fallback_seconds: 0) do |run_state, writer, thread|
      writer.write("t") # USR1 trapped; ready never follows
      assert_equal 4242, next_from(runner.marked_ready, "the fallback")
      assert run_state[:ready], "after the fallback, r goes straight to the app"
      refute run_state[:reload_pending]
      assert_equal [4242], runner.reload_signals

      writer.write(".") # a late report must find the pipe still open
      writer.close
      thread.join
      assert_equal [4242], runner.reload_signals, "a late ready report sends nothing more"
    end
  end

  def test_the_trap_report_alone_does_not_mark_the_app_ready
    runner = SignalRecorder.new
    watch_ready_pipe(runner, child_pid: 4242, ready_fallback_seconds: nil) do |run_state, writer, thread|
      writer.write("t")
      writer.close # the app exits before it is up
      thread.join
      refute run_state[:ready]
      assert run_state[:reload_pending]
      assert_empty runner.reload_signals
    end
  end

  def test_ready_report_after_the_trap_report_sends_a_queued_reload
    runner = SignalRecorder.new
    watch_ready_pipe(runner, child_pid: 4242, ready_fallback_seconds: nil) do |run_state, writer, thread|
      writer.write("t.")
      writer.close # what the harness does once it reports ready
      thread.join
      assert run_state[:ready]
      assert_equal [4242], runner.reload_signals
    end
  end

  def test_ready_fallback_for_a_replaced_app_does_not_touch_its_successor
    runner = SignalRecorder.new
    watch_ready_pipe(runner, child_pid: 2, watched_pid: 1, ready_fallback_seconds: 0) do |run_state, writer, thread|
      writer.write("t")
      assert_equal 1, next_from(runner.marked_ready, "the fallback") # the fallback for the replaced app ran out
      refute run_state[:ready]
      assert run_state[:reload_pending], "the successor's queued reload waits for the successor"
      assert_empty runner.reload_signals
      writer.close
      thread.join
    end
  end

  # After "R" and before the respawn, child_pid is still the old app's. Its
  # fallback (or a late ready report) used to mark the session up then, so
  # "r" in that gap signalled the reaped app, got ESRCH and ended the key
  # reader for the rest of the session.
  def test_a_ready_report_from_the_app_being_restarted_does_not_mark_the_session_up
    runner = SignalRecorder.new
    watch_ready_pipe(runner, child_pid: 4242, ready_fallback_seconds: 0) do |run_state, writer, thread|
      runner.send(:mark_restarting, run_state) # what "R" does before it kills the app
      run_state[:restart] = true
      writer.write("t") # the old app's fallback runs out during the restart
      assert_equal 4242, next_from(runner.marked_ready, "the fallback")
      refute run_state[:ready], "the app being replaced must not mark the session up"

      run_state[:restart] = false # the run loop has reaped the old app, no respawn yet
      out, = capture_io do
        assert runner.send(:handle_reload_command, "r", run_state), "r must not end the key reader"
      end
      assert_match(/queued/i, out)
      assert_empty runner.reload_signals, "nothing may be signalled before the respawn"
      writer.close
      thread.join
    end
  end

  # Records reload signals without sending them.
  class RecordingRunner < DummyRunner
    def reload_signals = (@reload_signals ||= [])

    def send_reload_signal(pid)
      reload_signals << pid
    end
  end

  # An app that reports ready just after "R" (it ignored TERM while booting,
  # or its byte was in flight) must not mark the CLI ready: the run loop then
  # clears the restart flag before the respawn, and an "r" in that gap would
  # signal the reaped app, get ESRCH and end the key reader.
  def test_a_ready_byte_from_the_app_r_retired_does_not_mark_it_ready
    runner = RecordingRunner.new
    retired = Process.spawn(RbConfig.ruby, "-e", "exit 0")
    Process.wait(retired)
    run_state = runner.send(:new_run_state, track_ready: true)
    run_state[:child_pid] = retired
    reader, writer = IO.pipe
    ready_thread = runner.send(:watch_child_ready, reader, retired, run_state)

    runner.send(:mark_restarting, run_state) # what "R" does before TERM
    writer.write(".")                        # the late ready byte
    writer.close
    ready_thread.join

    refute run_state[:ready], "the retired app's byte must not mark it ready"
    run_state[:restart] = false # the run loop reaped it and has not respawned yet
    out, = capture_io do
      assert runner.send(:handle_reload_command, "r", run_state), "r must not end the key reader"
    end
    assert_match(/queued/i, out)
    assert_empty runner.reload_signals, "nothing may be signalled while no app is up"
  end

  def test_a_respawned_app_with_the_retired_pid_can_report_ready
    runner = RecordingRunner.new
    run_state = runner.send(:new_run_state, track_ready: true)
    run_state[:child_pid] = 4242
    runner.send(:mark_restarting, run_state)
    # spawn_app_child for the next app clears the retired pid under the lock.
    run_state[:lock].synchronize { run_state[:retired_pid] = nil }
    reader, writer = IO.pipe
    ready_thread = runner.send(:watch_child_ready, reader, 4242, run_state)
    writer.write(".")
    writer.close
    ready_thread.join

    assert run_state[:ready]
  end

  def test_handle_reload_command_reports_dead_child
    runner = DummyRunner.new
    child = Process.spawn(RbConfig.ruby, "-e", "exit 0", pgroup: true)
    Process.wait2(child)
    run_state = { child_pid: child, restart: false }

    refute runner.send(:handle_reload_command, "R", run_state)
    refute run_state[:restart], "a dead child must not leave a pending restart flag"
  end

  def test_fetch_release_prefers_completed_prebuild_channel
    runner = DummyRunner.new
    releases = {
      "prebuild-main" => {
        "tag_name" => "prebuild-main",
        "assets" => [
          { "name" => "ruflet_client-manifest.json", "id" => 10, "updated_at" => "2026-07-15T12:00:00Z" },
          { "name" => "ruflet_client-linux-x64.tar.gz" }
        ]
      },
      "v0.0.18" => { "tag_name" => "v0.0.18", "assets" => [{ "name" => "ruflet_client-linux-x64.tar.gz" }] }
    }
    runner.define_singleton_method(:ruflet_version) { "0.0.18" }
    runner.define_singleton_method(:release_by_tag) { |tag| releases[tag] }
    runner.define_singleton_method(:release_latest) { nil }

    release = runner.send(
      :fetch_release_for_version,
      wanted_assets: [{ kind: :desktop, name: "ruflet_client-linux-x64.tar.gz", platform: "linux" }]
    )

    assert_equal "prebuild-main", release["tag_name"]
  end

  def test_fetch_release_ignores_prebuild_until_completion_manifest_exists
    runner = DummyRunner.new
    releases = {
      "prebuild-main" => {
        "tag_name" => "prebuild-main",
        "assets" => [{ "name" => "ruflet_client-linux-x64.tar.gz" }]
      },
      "v0.0.18" => {
        "tag_name" => "v0.0.18",
        "assets" => [{ "name" => "ruflet_client-linux-x64.tar.gz" }]
      }
    }
    runner.define_singleton_method(:ruflet_version) { "0.0.18" }
    runner.define_singleton_method(:release_by_tag) { |tag| releases[tag] }
    runner.define_singleton_method(:release_latest) { nil }

    release = runner.send(
      :fetch_release_for_version,
      wanted_assets: [{ kind: :desktop, name: "ruflet_client-linux-x64.tar.gz", platform: "linux" }]
    )

    assert_equal "v0.0.18", release["tag_name"]
  end

  def test_client_release_current_is_tracked_per_target
    runner = DummyRunner.new
    release = {
      "assets" => [
        { "name" => "ruflet_client-manifest.json", "id" => 10, "updated_at" => "2026-07-15T12:00:00Z", "size" => 120 }
      ]
    }
    revision = runner.send(:client_release_revision, release)
    manifest = {
      "targets" => [
        { "kind" => "desktop", "platform" => "linux", "release_revision" => revision },
        { "kind" => "web", "platform" => "linux", "release_revision" => "older" }
      ]
    }

    assert runner.send(
      :client_release_current?, manifest, release,
      [{ kind: :desktop, name: "ruflet_client-linux-x64.tar.gz", platform: "linux" }]
    )
    refute runner.send(
      :client_release_current?, manifest, release,
      [{ kind: :web, name: "ruflet_client-web.tar.gz" }]
    )
  end

  def test_client_update_interval_can_force_immediate_revalidation
    runner = DummyRunner.new
    previous = ENV["RUFLET_CLIENT_UPDATE_INTERVAL"]
    ENV["RUFLET_CLIENT_UPDATE_INTERVAL"] = "0"

    assert runner.send(:client_update_due?, { "checked_at" => Time.now.utc.iso8601 })
  ensure
    ENV["RUFLET_CLIENT_UPDATE_INTERVAL"] = previous
  end

  def test_existing_client_cache_refreshes_when_prebuild_revision_changes
    runner = DummyRunner.new
    previous_interval = ENV["RUFLET_CLIENT_UPDATE_INTERVAL"]
    ENV["RUFLET_CLIENT_UPDATE_INTERVAL"] = "0"

    Dir.mktmpdir do |dir|
      desktop = File.join(dir, "desktop")
      FileUtils.mkdir_p(desktop)
      stale_binary = File.join(desktop, "ruflet_client")
      File.write(stale_binary, "old")
      FileUtils.chmod(0o755, stale_binary)
      File.write(
        File.join(dir, "manifest.json"),
        JSON.generate(
          "targets" => [
            { "kind" => "desktop", "platform" => "linux", "release_revision" => "old" }
          ],
          "checked_at" => Time.now.utc.iso8601
        )
      )

      release = {
        "tag_name" => "prebuild-main",
        "published_at" => "2026-07-15T12:00:00Z",
        "assets" => [
          { "name" => "ruflet_client-manifest.json", "id" => 10, "updated_at" => "2026-07-15T12:00:00Z" },
          {
            "name" => "ruflet_client-linux-x64.tar.gz",
            "browser_download_url" => "https://example.test/client.tar.gz"
          }
        ]
      }
      runner.define_singleton_method(:ruflet_version) { "0.0.18" }
      runner.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      runner.define_singleton_method(:fetch_release_for_version) { |wanted_assets:| release }
      runner.define_singleton_method(:download_file) do |_url, destination, limit: 5|
        File.write(destination, "archive")
      end
      runner.define_singleton_method(:extract_archive) do |_archive, destination|
        FileUtils.mkdir_p(destination)
        extracted = File.join(destination, "ruflet_client")
        File.write(extracted, "new")
        FileUtils.chmod(0o755, extracted)
        true
      end

      root = runner.send(:ensure_prebuilt_client, desktop: true, platform: "linux")
      manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))

      assert_equal dir, root
      assert_equal "new", File.read(File.join(desktop, "ruflet_client"))
      assert_equal runner.send(:client_release_revision, release), manifest.dig("targets", 0, "release_revision")
    end
  ensure
    ENV["RUFLET_CLIENT_UPDATE_INTERVAL"] = previous_interval
  end

end
