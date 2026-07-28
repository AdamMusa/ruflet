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
      File.write(File.join(desktop, "ruflet_client"), "old")
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
        File.write(File.join(destination, "ruflet_client"), "new")
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
