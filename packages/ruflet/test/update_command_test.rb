# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliUpdateCommandTest < Minitest::Test
  class DummyUpdater
    include Ruflet::CLI::UpdateCommand
  end

  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  def test_command_update_check_reports_manifest_status
    updater = DummyUpdater.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")

      updater.define_singleton_method(:host_platform_name) { "macos" }
      updater.define_singleton_method(:ruflet_version) { "0.0.8" }
      updater.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      updater.define_singleton_method(:read_client_manifest) do |_root|
        { "release_tag" => "v0.0.8" }
      end
      updater.define_singleton_method(:prebuilt_desktop_present?) { |_root, platform: nil| platform == "macos" }

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      code = updater.command_update(["--check", "--web", "--desktop"])

      assert_equal 0, code
      assert_includes out.string, "Release tag: v0.0.8"
      assert_includes out.string, "web: installed"
      assert_includes out.string, "desktop: installed"
    ensure
      $stdout = original_stdout
    end
  end

  def test_command_update_downloads_requested_target_for_platform
    updater = DummyUpdater.new
    calls = []
    updater.define_singleton_method(:ensure_prebuilt_client) do |**kwargs|
      calls << kwargs
      "/tmp/ruflet-cache"
    end
    updater.define_singleton_method(:read_client_manifest) do |_root|
      { "release_tag" => "v0.0.8" }
    end

    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = updater.command_update(["desktop", "--platform", "linux"])

    assert_equal 0, code
    assert_equal [{ desktop: true, platform: "linux", force: false }], calls
    assert_includes out.string, "Updated desktop client for linux"
  ensure
    $stdout = original_stdout
  end

  def test_prepare_flutter_client_writes_local_ruby_runtime_override_before_pub_get
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      runtime_dir = File.join(dir, "ruby_runtime")
      FileUtils.mkdir_p(client_dir)
      FileUtils.mkdir_p(runtime_dir)
      File.write(File.join(runtime_dir, "pubspec.yaml"), "name: ruby_runtime\n")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            ruby_runtime: ^0.0.1
        YAML
      )

      calls = []
      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << chdir
        true
      end

      builder.send(:prepare_flutter_client, client_dir, tools: { env: {}, flutter: "flutter", dart: "dart" }, config: {})

      overrides = File.read(File.join(client_dir, "pubspec_overrides.yaml"))
      assert_includes overrides, "ruby_runtime:"
      assert_includes overrides, runtime_dir
      assert_includes calls, client_dir
    end
  end
end
