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

  def test_web_server_proxies_same_origin_websocket_without_runtime_globals
    runner = DummyRunner.new
    command = runner.send(:web_server_command, 8551, 8550)

    assert_equal ["python3", "-c"], command.first(2)
    assert_includes command.last, 'self.path.split("?", 1)[0] == "/ws"'
    assert_includes command.last, 'socket.create_connection(("127.0.0.1", 8550))'
    refute_includes command.last, "__RUFLET_URL__"
    assert_equal "http://localhost:8551/", runner.send(:web_client_url, 8551)
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

  def test_project_run_requires_managed_client_for_extension_services
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), <<~YAML)
        extensions:
          - map
          - audio-recorder
      YAML

      Dir.chdir(dir) do
        assert runner.send(:project_run_requires_managed_client?)
      end
    end
  end

  def test_project_run_does_not_require_managed_client_without_extensions
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "services.yaml"), <<~YAML)
        services:
          - unknown_service
      YAML

      Dir.chdir(dir) do
        refute runner.send(:project_run_requires_managed_client?)
      end
    end
  end

  def test_project_run_ignores_service_backed_extension_without_service
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "ruflet.yaml"), "extensions:\n  - camera\n")
      File.write(File.join(dir, "services.yaml"), "services: []\n")

      Dir.chdir(dir) do
        refute runner.send(:project_run_requires_managed_client?)
      end
    end
  end

  def test_project_desktop_client_command_prepares_extension_client
    runner = DummyRunner.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(client_dir)
      File.write(File.join(dir, "ruflet.yaml"), <<~YAML)
        extensions:
          - map
      YAML

      prepare_calls = []
      flutter_calls = []
      runner.define_singleton_method(:host_platform_name) { "macos" }
      runner.define_singleton_method(:ensure_ruflet_build_assets) { |verbose:| verbose == false }
      runner.define_singleton_method(:ensure_flutter_client_dir) { |verbose:| verbose == false ? client_dir : nil }
      runner.define_singleton_method(:ensure_flutter!) do |purpose, client_dir:|
        flutter_calls << { purpose: purpose, client_dir: client_dir }
        { env: { "PATH" => "/bin" }, flutter: "/fake/flutter" }
      end
      runner.define_singleton_method(:build_tool_env) do |env, platform, path|
        env.merge("RUFLET_PLATFORM" => platform, "RUFLET_CLIENT_DIR" => path)
      end
      runner.define_singleton_method(:prepare_flutter_client) do |path, platform:, tools:, config:, self_contained:, verbose:|
        prepare_calls << {
          path: path,
          platform: platform,
          tools: tools,
          config: config,
          self_contained: self_contained,
          verbose: verbose
        }
        true
      end

      Dir.chdir(dir) do
        cmd = runner.send(:detect_project_desktop_client_command, "http://localhost:8550")

        assert_equal [{ purpose: "run", client_dir: client_dir }], flutter_calls
        assert_equal 1, prepare_calls.length
        assert_equal ["map"], prepare_calls.first[:config]["extensions"]
        assert_equal false, prepare_calls.first[:self_contained]
        assert_equal false, prepare_calls.first[:verbose]
        assert_equal "macos", prepare_calls.first[:platform]
        assert_equal client_dir, prepare_calls.first[:path]
        assert_equal(
          [
            { "PATH" => "/bin", "RUFLET_PLATFORM" => "macos", "RUFLET_CLIENT_DIR" => client_dir },
            "/fake/flutter",
            "run",
            "-d",
            "macos",
            "--target",
            "lib/main.server.dart",
            "--dart-define",
            "RUFLET_BACKEND_URL=http://localhost:8550"
          ],
          cmd
        )
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
