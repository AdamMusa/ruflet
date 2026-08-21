# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"

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

  def build_ios_app(root, app_name = "Ruflet Explorer")
    app_bundle = File.join(root, "ios-experimental", "#{app_name}.app")
    FileUtils.mkdir_p(app_bundle)
    File.write(File.join(app_bundle, "Info.plist"), "plist")
    executable = File.join(app_bundle, app_name)
    File.write(executable, "binary")
    FileUtils.chmod(0o755, executable)
    app_bundle
  end

  def test_run_options_accept_experimental_and_exp_aliases
    runner = DummyRunner.new

    args = ["--experimental", "main"]
    options = runner.send(:parse_run_options, args)
    assert options[:experimental]
    assert_equal ["main"], args

    args = ["--exp", "main"]
    options = runner.send(:parse_run_options, args)
    assert options[:experimental]
    assert_equal ["main"], args
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

  def test_experimental_macos_prebuilt_uses_a_separate_complete_bundle
    skip "macOS layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    Dir.mktmpdir do |dir|
      expected = build_macos_app(
        File.join(dir, "desktop-experimental"), "Ruflet Explorer")

      assert DummyRunner.new.send(
        :prebuilt_experimental_desktop_present?, dir, platform: "macos")
      command = DummyRunner.new.send(
        :detect_desktop_client_command,
        "http://127.0.0.1:8550", root: dir, experimental: true)
      assert_equal [expected, "http://127.0.0.1:8550"], command
    end
  end

  def test_prepare_experimental_desktop_selects_macos_prebuilt
    runner = DummyRunner.new
    requested = nil
    runner.define_singleton_method(:host_platform_name) { "macos" }
    runner.define_singleton_method(:ensure_prebuilt_client) do |**options|
      requested = options
      "/tmp/ruflet-experimental"
    end

    client = runner.send(
      :prepare_experimental_run_client,
      target: "desktop", experimental: true)

    assert_equal({ desktop_experimental: true, platform: "macos" }, requested)
    assert_equal({ kind: :desktop, root: "/tmp/ruflet-experimental" }, client)
  end

  def test_experimental_desktop_launch_uses_downloaded_native_client
    runner = DummyRunner.new
    launched = nil
    runner.define_singleton_method(:wait_for_server_boot) { |_port| true }
    runner.define_singleton_method(:launch_desktop_client) do |url, root: nil, experimental: false|
      launched = { url: url, root: root, experimental: experimental }
      [321]
    end

    result = runner.send(
      :launch_target_client, "desktop", 8550,
      experimental_client: { kind: :desktop, root: "/tmp/ruflet-experimental" })

    assert_equal [321], result
    assert_equal(
      {
        url: "http://localhost:8550",
        root: "/tmp/ruflet-experimental",
        experimental: true
      },
      launched)
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

  def test_prebuilt_assets_present_requires_a_complete_experimental_ios_app
    Dir.mktmpdir do |dir|
      refute DummyRunner.new.send(
        :prebuilt_assets_present?, dir,
        web: false, desktop: false, ios_experimental: true, platform: "macos"
      )

      expected = build_ios_app(dir)

      assert_equal expected, DummyRunner.new.send(:experimental_ios_app_bundle, dir)
      assert DummyRunner.new.send(
        :prebuilt_assets_present?, dir,
        web: false, desktop: false, ios_experimental: true, platform: "macos"
      )
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
    assert runner.send(
      :release_asset_matches?,
      "ruflet_explorer-ios-experimental-simulator.zip", :ios_experimental, "macos"
    )
    assert runner.send(
      :release_asset_matches?,
      "ruflet_explorer-macos-experimental-universal.zip", :desktop_experimental, "macos"
    )
    refute runner.send(
      :release_asset_matches?,
      "ruflet_explorer-macos-experimental-universal.zip", :desktop, "macos"
    )

    refute runner.send(:release_asset_matches?, "some_other_explorer-web.tar.gz", :web, nil)
    refute runner.send(
      :release_asset_matches?,
      "ruflet_explorer-ios-simulator.zip", :ios_experimental, "macos"
    )
  end

  def test_wanted_asset_names_use_the_explorer_prefix
    runner = DummyRunner.new

    assert_equal "ruflet_explorer-macos-universal.zip", runner.send(:desktop_asset_name_for, "macos")
    assert_equal "ruflet_explorer-linux-x64.tar.gz", runner.send(:desktop_asset_name_for, "linux")
    assert_equal "ruflet_explorer-windows-x64.zip", runner.send(:desktop_asset_name_for, "windows")
    assert_equal "ruflet_explorer-ios-experimental-simulator.zip", Ruflet::CLI::RunCommand::EXPERIMENTAL_IOS_SIMULATOR_ASSET
    assert_equal "ruflet_explorer-macos-experimental-universal.zip", Ruflet::CLI::RunCommand::EXPERIMENTAL_MACOS_ASSET
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

  def test_prebuilt_client_installs_experimental_ios_simulator_asset
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      release = {
        "tag_name" => "prebuild-main",
        "assets" => [
          { "name" => "ruflet_explorer-manifest.json", "id" => 8, "updated_at" => "2026-08-20T00:00:00Z" },
          {
            "name" => "ruflet_explorer-ios-experimental-simulator.zip",
            "browser_download_url" => "https://example.test/ios-experimental.zip"
          }
        ]
      }
      runner.define_singleton_method(:ruflet_version) { "0.0.21" }
      runner.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      runner.define_singleton_method(:fetch_release_for_version) { |wanted_assets:| release }
      runner.define_singleton_method(:download_file) { |_url, destination, limit: 5| File.write(destination, "archive") }
      runner.define_singleton_method(:extract_archive) do |_archive, destination|
        app_bundle = File.join(destination, "Ruflet Explorer.app")
        FileUtils.mkdir_p(app_bundle)
        File.write(File.join(app_bundle, "Info.plist"), "plist")
        executable = File.join(app_bundle, "Ruflet Explorer")
        File.write(executable, "binary")
        FileUtils.chmod(0o755, executable)
        true
      end

      root = runner.send(:ensure_prebuilt_client, ios_experimental: true, platform: "macos")
      manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))

      assert_equal dir, root
      assert runner.send(
        :prebuilt_assets_present?, dir,
        web: false, desktop: false, ios_experimental: true, platform: "macos"
      )
      assert_equal "ios_experimental", manifest.fetch("targets").last.fetch("kind")
    end
  end

  def test_prebuilt_client_installs_experimental_macos_asset_separately
    runner = DummyRunner.new
    app_builder = method(:build_macos_app)

    Dir.mktmpdir do |dir|
      release = {
        "tag_name" => "prebuild-main",
        "assets" => [
          { "name" => "ruflet_explorer-manifest.json", "id" => 9, "updated_at" => "2026-08-20T00:00:00Z" },
          {
            "name" => "ruflet_explorer-macos-experimental-universal.zip",
            "browser_download_url" => "https://example.test/macos-experimental.zip"
          }
        ]
      }
      runner.define_singleton_method(:ruflet_version) { "0.0.21" }
      runner.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      runner.define_singleton_method(:fetch_release_for_version) { |wanted_assets:| release }
      runner.define_singleton_method(:download_file) { |_url, destination, limit: 5| File.write(destination, "archive") }
      runner.define_singleton_method(:extract_archive) do |_archive, destination|
        app_builder.call(destination, "Ruflet Explorer")
        true
      end

      root = runner.send(
        :ensure_prebuilt_client,
        desktop_experimental: true, platform: "macos")
      manifest = JSON.parse(File.read(File.join(dir, "manifest.json")))

      assert_equal dir, root
      assert runner.send(
        :prebuilt_assets_present?, dir,
        web: false, desktop: false, desktop_experimental: true, platform: "macos")
      assert_equal "desktop_experimental", manifest.fetch("targets").last.fetch("kind")
      refute Dir.exist?(File.join(dir, "desktop"))
    end
  end

  def test_experimental_mobile_launch_installs_and_passes_backend_to_simulator
    runner = DummyRunner.new
    calls = []
    runner.define_singleton_method(:system) do |*args|
      calls << args
      true
    end
    client = {
      app_bundle: "/tmp/Ruflet Explorer.app",
      bundle_identifier: "com.izeesoft.rufletExplorer",
      simulator_udid: "SIM-123",
      simulator_name: "iPhone 17 Pro Max"
    }

    result = runner.send(
      :launch_experimental_mobile_client,
      "http://192.168.1.226:8550",
      client: client
    )

    assert_equal [], result
    assert_equal ["xcrun", "simctl", "install", "SIM-123", "/tmp/Ruflet Explorer.app"], calls[0]
    assert_equal({ "SIMCTL_CHILD_RUFLET_URL" => "http://192.168.1.226:8550" }, calls[1][0])
    assert_equal [
      "xcrun", "simctl", "launch", "--terminate-running-process", "SIM-123", "com.izeesoft.rufletExplorer"
    ], calls[1][1..]
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

  def test_fetch_release_uses_experimental_channel_for_exp_assets
    runner = DummyRunner.new
    releases = {
      "prebuild-experimental" => {
        "tag_name" => "prebuild-experimental",
        "assets" => [
          { "name" => "ruflet_client-manifest.json", "id" => 11, "updated_at" => "2026-08-21T12:00:00Z" },
          { "name" => "ruflet_explorer-ios-experimental-simulator.zip" }
        ]
      }
    }
    runner.define_singleton_method(:release_by_tag) { |tag| releases[tag] }
    runner.define_singleton_method(:release_latest) { nil }

    release = runner.send(
      :fetch_release_for_version,
      wanted_assets: [
        {
          kind: :ios_experimental,
          name: "ruflet_explorer-ios-experimental-simulator.zip",
          platform: "macos"
        }
      ]
    )

    assert_equal "prebuild-experimental", release["tag_name"]
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
