# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "rbconfig"

class RufletCliRunCommandTest < Minitest::Test
  class DummyRunner
    include Ruflet::CLI::RunCommand
    include Ruflet::CLI::BuildCommand
  end

  def test_find_nearest_gemfile_walks_up_directories
    Dir.mktmpdir do |dir|
      root = File.join(dir, "repo")
      nested = File.join(root, "examples", "showcase")
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

  def test_web_client_opens_clean_backend_origin_without_python_proxy
    runner = DummyRunner.new
    opened = []
    runner.define_singleton_method(:open_in_browser_app_mode) { |url| opened << [:app, url]; nil }
    runner.define_singleton_method(:open_in_browser) { |url| opened << [:browser, url] }

    pids = nil
    out, = capture_io { pids = runner.send(:launch_web_client, 8551) }

    # The prebuilt client derives its WebSocket backend from its own origin.
    url = "http://localhost:8551/"
    assert_equal [[:app, url], [:browser, url]], opened
    assert_includes out, url
    assert_equal [], pids
    # The Python static-server/proxy is gone entirely.
    refute runner.respond_to?(:web_server_command, true)
    refute runner.respond_to?(:web_client_url, true)
  end

  def test_client_release_defaults_to_exact_version_tags
    runner = DummyRunner.new

    with_env("RUFLET_CLIENT_CHANNEL" => nil) do
      assert_equal ["v#{Ruflet::VERSION}", Ruflet::VERSION], runner.send(:client_release_tags)
    end
  end

  def test_client_release_channel_is_explicit
    runner = DummyRunner.new

    with_env("RUFLET_CLIENT_CHANNEL" => "prebuild-main") do
      assert_equal ["prebuild-main"], runner.send(:client_release_tags)
    end
  end

  def test_client_release_never_falls_back_to_latest
    runner = DummyRunner.new
    requested = []
    runner.define_singleton_method(:release_by_tag) do |tag|
      requested << tag
      nil
    end

    with_env("RUFLET_CLIENT_CHANNEL" => nil) do
      assert_nil runner.send(:fetch_release_for_version)
    end
    assert_equal ["v#{Ruflet::VERSION}", Ruflet::VERSION], requested
  end

  def test_client_cache_requires_matching_version_platform_and_release
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      manifest = {
        "schema" => 1,
        "ruflet_version" => Ruflet::VERSION,
        "platform" => "macos",
        "release_tag" => "v#{Ruflet::VERSION}"
      }
      File.write(File.join(dir, "manifest.json"), JSON.generate(manifest))

      with_env("RUFLET_CLIENT_CHANNEL" => nil) do
        assert runner.send(:compatible_client_cache?, dir, platform: "macos")
        manifest["release_tag"] = "Beta"
        File.write(File.join(dir, "manifest.json"), JSON.generate(manifest))
        refute runner.send(:compatible_client_cache?, dir, platform: "macos")
      end
    end
  end

  def test_run_targets_have_separate_default_backend_ports
    runner = DummyRunner.new

    assert_equal 8550, runner.send(:default_backend_port, "web")
    assert_equal 8560, runner.send(:default_backend_port, "desktop")
    assert_equal 8570, runner.send(:default_backend_port, "mobile")
    assert_equal 8570, runner.send(:default_backend_port, "unknown")
  end

  def test_resolve_backend_port_starts_from_target_default_without_explicit_port
    runner = DummyRunner.new
    starts = []
    runner.define_singleton_method(:find_available_port) do |start_port, **_options|
      starts << start_port
      start_port
    end

    assert_equal 8550, runner.send(:resolve_backend_port, "web")
    assert_equal 8560, runner.send(:resolve_backend_port, "desktop")
    assert_equal 8570, runner.send(:resolve_backend_port, "mobile")
    assert_equal [8550, 8560, 8570], starts
  end

  def test_resolve_backend_port_keeps_explicit_port_as_base
    runner = DummyRunner.new
    runner.define_singleton_method(:find_available_port) { |start_port, **_options| start_port }

    assert_equal 9000, runner.send(:resolve_backend_port, "desktop", requested_port: 9000)
  end

  def test_resolve_backend_port_skips_port_used_by_another_run
    runner = DummyRunner.new
    busy_port = 9123
    runner.define_singleton_method(:port_available?) { |port| port != busy_port }

    selected = runner.send(:resolve_backend_port, "web", requested_port: busy_port)

    assert_equal busy_port + 1, selected
  end

  def test_resolve_backend_port_fails_cleanly_when_range_is_exhausted
    runner = DummyRunner.new
    runner.define_singleton_method(:port_available?) { |_port| false }

    _out, err = capture_io do
      assert_nil runner.send(:resolve_backend_port, "mobile", requested_port: 9200)
    end

    assert_includes err, "No available Ruflet port found starting at 9200."
  end

  def test_prebuilt_macos_desktop_presence_repairs_missing_file_picker_entitlement
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      app_dir = File.join(dir, "desktop", "ruflet_client.app")
      bin = File.join(app_dir, "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(bin))
      File.write(bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", bin)

      checks = [false, true]
      calls = []
      runner.define_singleton_method(:host_platform_name) { "macos" }
      runner.define_singleton_method(:macos_app_has_file_picker_entitlement?) { |_path| checks.shift }
      runner.define_singleton_method(:system) do |*args, **_kwargs|
        calls << args
        true
      end

      assert runner.send(:prebuilt_desktop_present?, dir, platform: "macos")
      assert_equal "/usr/bin/codesign", calls.first[0]
      assert_includes calls.first, "--entitlements"
      assert_includes calls.first, app_dir
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

  def test_desktop_client_launch_never_builds_from_source
    runner = DummyRunner.new

    refute runner.respond_to?(:detect_project_desktop_client_command, true),
           "ruflet run must launch the prebuilt client, never compile one from source"

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), <<~YAML)
        extensions:
          - map
          - code_editor
          - rive
        services:
          - camera
          - geolocator
      YAML

      detect_calls = []
      runner.define_singleton_method(:detect_desktop_client_command) do |url|
        detect_calls << url
        nil
      end

      Dir.chdir(dir) do
        runner.send(:launch_desktop_client, "http://localhost:8550")
      end

      assert_equal ["http://localhost:8550"], detect_calls
    end
  end

  def test_web_client_ignores_implicit_project_checkout_and_uses_release_cache
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      project_web = File.join(dir, "ruflet_client", "build", "web")
      release_root = File.join(dir, "github-release-cache")
      release_web = File.join(release_root, "web")
      FileUtils.mkdir_p(project_web)
      FileUtils.mkdir_p(release_web)
      File.write(File.join(project_web, "index.html"), "project build")
      File.write(File.join(release_web, "index.html"), "release prebuild")

      calls = []
      runner.define_singleton_method(:ensure_prebuilt_client) do |**options|
        calls << options
        release_root
      end

      with_env("RUFLET_CLIENT_DIR" => nil) do
        Dir.chdir(dir) do
          assert_equal release_web, runner.send(:detect_web_client_dir)
        end
      end
      assert_equal [{ web: true }], calls
    end
  end

  def test_macos_desktop_client_detection_ignores_local_flutter_build
    skip "macOS-specific desktop bundle layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      release_bin = File.join(dir, "ruflet_client", "build", "macos", "Build", "Products", "Release", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(release_bin))
      File.write(release_bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", release_bin)

      desktop_bin = File.join(dir, "ruflet_client", "desktop", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(desktop_bin))
      File.write(desktop_bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", desktop_bin)

      runner.define_singleton_method(:ensure_macos_file_picker_entitlement) { |_app_path| true }

      with_env("RUFLET_CLIENT_DIR" => File.join(dir, "ruflet_client")) do
        command = runner.send(:detect_desktop_client_command, "http://localhost:8550")

        assert_equal [desktop_bin, "http://localhost:8550"], command
      end
    end
  end

  def test_macos_desktop_client_detection_never_returns_build_artifact
    skip "macOS-specific desktop bundle layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      release_bin = File.join(dir, "ruflet_client", "build", "macos", "Build", "Products", "Release", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(release_bin))
      File.write(release_bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", release_bin)

      runner.define_singleton_method(:ensure_prebuilt_client) { |**_options| nil }

      with_env("RUFLET_CLIENT_DIR" => File.join(dir, "ruflet_client")) do
        assert_nil runner.send(:detect_desktop_client_command, "http://localhost:8550")
      end
    end
  end

  def test_macos_desktop_client_detection_falls_back_to_cached_desktop_app
    skip "macOS-specific desktop bundle layout" unless RbConfig::CONFIG["host_os"].match?(/darwin/i)

    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      local_build_bin = File.join(dir, "project", "ruflet_client", "build", "macos", "Build", "Products", "Release", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(local_build_bin))
      File.write(local_build_bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", local_build_bin)

      cached_bin = File.join(dir, "cache", "desktop", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
      FileUtils.mkdir_p(File.dirname(cached_bin))
      File.write(cached_bin, "#!/bin/sh\n")
      FileUtils.chmod("+x", cached_bin)

      runner.define_singleton_method(:ensure_macos_file_picker_entitlement) { |_app_path| true }
      runner.define_singleton_method(:ensure_prebuilt_client) { |**_options| File.join(dir, "cache") }

      Dir.chdir(File.join(dir, "project")) do
        command = runner.send(:detect_desktop_client_command, "http://localhost:8550")

        assert_equal [cached_bin, "http://localhost:8550"], command
      end
    end
  end

  def test_service_extension_config_applies_microphone_native_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "microphone")

      runner.send(:apply_service_extension_config, dir, { "services" => ["audio_recorder"] })

      assert_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.RECORD_AUDIO"
      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "DebugProfile.entitlements")), "com.apple.security.device.audio-input"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Release.entitlements")), "com.apple.security.device.audio-input"
    end
  end

  def test_service_extension_config_reads_native_requirements_from_services_yaml
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      File.write(File.join(dir, "services.yaml"), <<~YAML)
        services:
          - camera:
              native:
                android_permissions:
                  - android.permission.CAMERA
                ios_info:
                  NSCameraUsageDescription: Custom camera reason.
                ios_permission_definitions:
                  - PERMISSION_CAMERA=1
      YAML

      runner.send(:apply_service_extension_config, dir, { "services" => ["camera"] })

      assert_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.CAMERA"
      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "Custom camera reason."
      assert_includes File.read(File.join(dir, "ios", "Podfile")), "PERMISSION_CAMERA=1"
      refute_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.RECORD_AUDIO"
    end
  end

  def test_service_extension_config_removes_yaml_defined_stale_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      File.write(File.join(dir, "services.yaml"), <<~YAML)
        services:
          - camera:
              native:
                android_permissions:
                  - android.permission.CAMERA
                ios_info:
                  NSCameraUsageDescription: Camera reason.
      YAML

      runner.send(:apply_service_extension_config, dir, { "services" => ["camera"] })
      File.write(File.join(dir, "services.yaml"), "services: []\n")
      runner.send(:apply_service_extension_config, dir, { "services" => [] })

      refute_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.CAMERA"
      refute_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSCameraUsageDescription"
    end
  end

  def test_service_extension_config_applies_motion_usage_description
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "motion")

      runner.send(:apply_service_extension_config, dir, { "services" => ["barometer"] })

      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMotionUsageDescription"
    end
  end

  def test_service_extension_config_applies_location_native_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "location")

      runner.send(:apply_service_extension_config, dir, { "services" => ["geolocator"] })

      android_manifest = File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml"))
      assert_includes android_manifest, "android.permission.ACCESS_FINE_LOCATION"
      assert_includes android_manifest, "android.permission.ACCESS_COARSE_LOCATION"
      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSLocationWhenInUseUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSLocationUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "DebugProfile.entitlements")), "com.apple.security.personal-information.location"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Release.entitlements")), "com.apple.security.personal-information.location"
    end
  end

  def test_service_extension_config_enables_camera_and_microphone_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "camera", "microphone")

      runner.send(:apply_service_extension_config, dir, { "services" => ["permission_handler"] })

      podfile = File.read(File.join(dir, "ios", "Podfile"))
      assert_includes podfile, "PERMISSION_CAMERA=1"
      assert_includes podfile, "PERMISSION_MICROPHONE=1"
      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSCameraUsageDescription"
      assert_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSCameraUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      assert_includes File.read(File.join(dir, "macos", "Runner", "DebugProfile.entitlements")), "com.apple.security.device.camera"
      assert_includes File.read(File.join(dir, "macos", "Runner", "Release.entitlements")), "com.apple.security.device.audio-input"
    end
  end

  def test_service_extension_config_removes_stale_ios_permission_definitions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "camera", "microphone")
      runner.send(:apply_service_extension_config, dir, { "services" => ["permission_handler"] })

      write_services_file(dir)
      runner.send(:apply_service_extension_config, dir, { "services" => [] })

      podfile = File.read(File.join(dir, "ios", "Podfile"))
      refute_includes podfile, "PERMISSION_CAMERA=1"
      refute_includes podfile, "PERMISSION_MICROPHONE=1"
    end
  end

  def test_service_extension_config_keeps_microphone_permission_out_when_not_requested
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "camera")

      runner.send(:apply_service_extension_config, dir, { "services" => ["map"] })

      refute_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.RECORD_AUDIO"
      refute_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      refute_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      refute_includes File.read(File.join(dir, "macos", "Runner", "DebugProfile.entitlements")), "com.apple.security.device.audio-input"
      refute_includes File.read(File.join(dir, "macos", "Runner", "Release.entitlements")), "com.apple.security.device.audio-input"
    end
  end

  def test_service_extension_config_removes_stale_microphone_native_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "microphone")
      runner.send(:apply_service_extension_config, dir, { "services" => ["audio_recorder"] })

      write_services_file(dir)
      runner.send(:apply_service_extension_config, dir, { "services" => [] })

      refute_includes File.read(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml")), "android.permission.RECORD_AUDIO"
      refute_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      refute_includes File.read(File.join(dir, "macos", "Runner", "Info.plist")), "NSMicrophoneUsageDescription"
      refute_includes File.read(File.join(dir, "macos", "Runner", "DebugProfile.entitlements")), "com.apple.security.device.audio-input"
      refute_includes File.read(File.join(dir, "macos", "Runner", "Release.entitlements")), "com.apple.security.device.audio-input"
    end
  end

  def test_service_extension_config_removes_stale_motion_native_permissions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      make_client_native_files(dir)
      write_services_file(dir, "motion")
      runner.send(:apply_service_extension_config, dir, { "services" => ["barometer"] })

      write_services_file(dir)
      runner.send(:apply_service_extension_config, dir, { "services" => [] })

      refute_includes File.read(File.join(dir, "ios", "Runner", "Info.plist")), "NSMotionUsageDescription"
    end
  end

  private

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    previous&.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def make_client_native_files(dir)
    FileUtils.mkdir_p(File.join(dir, "android", "app", "src", "main"))
    FileUtils.mkdir_p(File.join(dir, "ios", "Runner"))
    FileUtils.mkdir_p(File.join(dir, "macos", "Runner"))
    File.write(File.join(dir, "pubspec.yaml"), "name: demo\n")
    File.write(File.join(dir, "android", "app", "src", "main", "AndroidManifest.xml"), <<~XML)
      <manifest xmlns:android="http://schemas.android.com/apk/res/android">
          <application android:label="Demo"/>
      </manifest>
    XML
    File.write(File.join(dir, "ios", "Runner", "Info.plist"), minimal_plist)
    File.write(File.join(dir, "ios", "Podfile"), <<~RUBY)
      post_install do |installer|
        installer.pods_project.targets.each do |target|
          flutter_additional_ios_build_settings(target)
        end
      end
    RUBY
    File.write(File.join(dir, "macos", "Runner", "Info.plist"), minimal_plist)
    %w[DebugProfile Release].each do |name|
      File.write(File.join(dir, "macos", "Runner", "#{name}.entitlements"), minimal_plist)
    end
  end

  def write_services_file(dir, *services)
    File.write(
      File.join(dir, "services.yaml"),
      YAML.dump("services" => services)
    )
  end

  def minimal_plist
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      </dict>
      </plist>
    PLIST
  end

end
