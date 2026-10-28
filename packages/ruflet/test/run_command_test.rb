# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "timeout"

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

  def test_handle_reload_command_big_r_requests_full_restart
    runner = DummyRunner.new
    child = Process.spawn(RbConfig.ruby, "-e", "sleep 30", pgroup: true)
    run_state = { child_pid: child, restart: false }

    assert runner.send(:handle_reload_command, "R", run_state)
    assert run_state[:restart], "R must flag a full restart before terminating the child"
    _pid, status = Process.wait2(child)
    assert status.signaled?, "R must terminate the child process group"
  ensure
    begin
      Process.kill("KILL", -child) if child
    rescue Errno::ESRCH, Errno::EPERM
      # ESRCH: already reaped. EPERM: the runner denies signalling the group.
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
      run_state = runner.send(:new_run_state, track_ready: true)

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
