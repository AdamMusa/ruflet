# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# `ruflet build` targets and options and `ruflet install` device handling,
# driven through command_build / command_install with Flutter stubbed.
class RufletCliBuildOptionsTest < Minitest::Test
  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  BACKEND = { "app" => { "backend_url" => "https://api.example.test" } }.freeze

  def test_missing_and_unsupported_targets_fail_with_usage
    in_project do |dir|
      builder = builder_for(dir)
      _out, err = capture_io { assert_equal 1, builder.command_build([]) }
      assert_includes err, "Usage: ruflet build <apk|android|aab|appbundle|ios|ipa|web|macos|windows|linux>"

      _out, err = capture_io { assert_equal 1, builder.command_build(["pdf"]) }
      assert_includes err, "Unsupported build target: pdf"
      assert_nil builder.calls[:prepared_platform]
    end
  end

  def test_every_target_maps_to_its_flutter_build
    {
      "apk" => [["build", "apk"], "apk"],
      "android" => [["build", "apk"], "android"],
      "aab" => [["build", "appbundle"], "aab"],
      # Flutter's spelling is normalized, so the identity and stale-asset
      # checks that look for "aab" apply to it too.
      "appbundle" => [["build", "appbundle"], "aab"],
      "ios" => [["build", "ios", "--codesign"], "ios"],
      "ipa" => [["build", "ipa"], "ios"],
      "web" => [["build", "web"], "web"],
      "macos" => [["build", "macos"], "macos"],
      "windows" => [["build", "windows"], "windows"],
      "linux" => [["build", "linux"], "linux"],
      "APK" => [["build", "apk"], "apk"]
    }.each do |target, (flutter_args, prepared)|
      in_project do |dir|
        builder = builder_for(dir, config: BACKEND)
        capture_io { assert_equal 0, builder.command_build([target]), target }
        assert_equal ["flutter", *flutter_args], builder.calls[:flutter].first.first(flutter_args.size + 1), target
        assert_equal prepared, builder.calls[:prepared_platform], target
        assert_includes builder.calls[:flutter].first, "RUFLET_BACKEND_URL=https://api.example.test", target
      end
    end
  end

  def test_mobile_server_builds_need_a_backend_url_but_web_and_desktop_do_not
    %w[apk aab ipa].each do |target|
      in_project do |dir|
        builder = builder_for(dir)
        _out, err = capture_io { assert_equal 1, builder.command_build([target]), target }
        assert_includes err, "backend_url is required for server-driven builds"
        assert_nil builder.calls[:flutter], target
      end
    end

    %w[web macos windows linux].each do |target|
      in_project do |dir|
        builder = builder_for(dir)
        out, = capture_io { assert_equal 0, builder.command_build([target]), target }
        assert_includes out, "the #{target} client will resolve its server at launch"
      end
    end
  end

  def test_verbose_aliases_and_flutter_passthrough_arguments
    ["--verbose", "-v"].each do |flag|
      in_project do |dir|
        builder = builder_for(dir, config: BACKEND)
        out, = capture_io { builder.command_build(["apk", flag, "--split-per-abi"]) }
        args = builder.calls[:flutter].first
        assert_equal ["flutter", "build", "apk", "--split-per-abi"], args.first(4), flag
        assert_equal 1, args.count("-v"), flag
        assert_includes out, "[ruflet build] mode=server", flag
      end
    end
  end

  def test_ios_codesign_flag_is_added_only_for_an_unsigned_device_build
    {
      ["ios"] => 1,
      ["ios", "--simulator"] => 0,
      ["ios", "--no-codesign"] => 0,
      ["ios", "--codesign"] => 1
    }.each do |argv, expected|
      in_project do |dir|
        builder = builder_for(dir, config: BACKEND)
        capture_io { builder.command_build(argv.dup) }
        assert_equal expected, builder.calls[:flutter].first.count("--codesign"), argv.inspect
      end
    end
  end

  def test_an_explicit_simulator_self_build_runs_one_pass
    in_project do |dir|
      builder = builder_for(dir)
      builder.define_singleton_method(:configure_platform_autostart) { |*_args, **_opts| nil }
      builder.define_singleton_method(:stage_ios_simulator_ruby_runtime) { |*_args, **_opts| true }

      capture_io { assert_equal 0, builder.command_build(["ios", "--self", "--simulator"]) }
      assert_equal 1, builder.calls[:flutter].size
      refute_includes builder.calls[:flutter].first, "--codesign"
    end
  end

  def test_failed_preparation_or_flutter_build_fails_the_command
    in_project do |dir|
      builder = builder_for(dir, config: BACKEND, prepared: false)
      capture_io { assert_equal 1, builder.command_build(["apk"]) }
      assert_nil builder.calls[:flutter]

      builder = builder_for(dir, config: BACKEND, flutter_ok: false)
      builder.define_singleton_method(:export_platform_build_outputs) { |*_args, **_opts| flunk("nothing to export") }
      capture_io { assert_equal 1, builder.command_build(["apk"]) }
    end
  end

  def test_missing_client_fails_before_flutter
    in_project do |dir|
      builder = builder_for(dir)
      builder.define_singleton_method(:ensure_flutter_client_dir) { |verbose: false| nil }
      _out, err = capture_io { assert_equal 1, builder.command_build(["web"]) }
      assert_includes err, "Could not find Flutter client directory."
    end
  end

  # A partial signing setup used to print "build config error" and build
  # anyway, leaving whatever key.properties an earlier build wrote.
  def test_partial_android_signing_fails_the_build
    in_project do |dir|
      client = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client, "android"))
      stale = File.join(client, "android", "key.properties")
      File.write(stale, "storeFile=/old/release.jks\n")

      builder = DummyBuilder.new
      builder.define_singleton_method(:refresh_managed_client_template_files) { |*_args, **_opts| true }
      builder.define_singleton_method(:remove_native_apple_renderer_integration) { |*_args, **_opts| true }
      builder.define_singleton_method(:sync_client_metadata) { |*_args, **_opts| nil }
      builder.define_singleton_method(:apply_native_service_permissions) { |*_args| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |*_args, **_opts| flunk("must stop at the signing error") }

      with_env("RUFLET_ANDROID_KEYSTORE" => "release.jks", "RUFLET_ANDROID_KEYSTORE_PASSWORD" => nil,
               "RUFLET_ANDROID_KEY_ALIAS" => nil, "RUFLET_ANDROID_KEY_PASSWORD" => nil) do
        _out, err = capture_io do
          refute builder.send(:prepare_flutter_client, client, platform: "apk", tools: { env: {}, flutter: "flutter" }, config: {})
        end
        assert_includes err, "build config error: Android signing is missing storePassword, keyAlias, keyPassword"
      end
      assert_equal "storeFile=/old/release.jks\n", File.read(stale)
    end
  end

  def test_install_device_ids_select_the_outputs_to_sync
    builder = DummyBuilder.new
    {
      "emulator-5554" => "android",
      "R58M123ABCD" => "android",
      "192.168.1.20:5555" => "android",
      "adb-R58M123ABCD-x1Yz._adb-tls-connect._tcp" => "android",
      "00008030-001A2D3C0E12802E" => "ios",
      "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678" => "ios",
      "6B29FC40-CA47-1067-B31D-00DD010662DA" => "ios",
      "macos" => "macos",
      "linux" => "linux",
      "windows" => "windows",
      "chrome" => "web",
      "edge" => "web",
      "web-server" => "web"
    }.each do |device_id, platform|
      assert_equal platform, builder.send(:install_platform_for_device, device_id), device_id
    end
  end

  def test_install_short_device_flag_and_verbose
    [["-d", "emulator-5554"], ["--device", "emulator-5554"]].each do |device_args|
      in_project do |dir|
        builder = installer_for(dir)
        capture_io { assert_equal 0, builder.command_install([*device_args, "-v"]) }
        assert_equal ["flutter", "install", "-d", "emulator-5554", "-v"], builder.calls[:flutter].first, device_args.inspect
      end
    end
  end

  def test_install_fails_without_a_client_or_when_flutter_install_fails
    in_project do |dir|
      builder = installer_for(dir)
      builder.define_singleton_method(:ensure_flutter_client_dir) { |verbose: false| nil }
      _out, err = capture_io { assert_equal 1, builder.command_install(["-d", "emulator-5554"]) }
      assert_includes err, "Could not find Flutter client directory."

      builder = installer_for(dir, flutter_ok: false)
      capture_io { assert_equal 1, builder.command_install(["-d", "emulator-5554"]) }
    end
  end

  def test_config_path_falls_back_to_ruflet_yml
    in_project do
      builder = DummyBuilder.new
      with_env("RUFLET_CONFIG" => nil) do
        assert_equal "ruflet.yaml", builder.send(:ruflet_config_path)
        File.write("ruflet.yml", "app:\n  backend_url: https://yml.example.test\n")
        assert_equal "ruflet.yml", builder.send(:ruflet_config_path)
        File.write("ruflet.yaml", "app:\n  backend_url: https://yaml.example.test\n")
        assert_equal "ruflet.yaml", builder.send(:ruflet_config_path)
      end

      File.write("custom.yaml", "app:\n  backend_url: https://custom.example.test\n")
      with_env("RUFLET_CONFIG" => "custom.yaml") do
        assert_equal "custom.yaml", builder.send(:ruflet_config_path)
        assert_equal "https://custom.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
      end

      # A RUFLET_CONFIG naming a missing file loads ruflet.yml, and asset
      # configuration now resolves the same file instead of none.
      File.delete("ruflet.yaml")
      with_env("RUFLET_CONFIG" => "missing.yaml") do
        assert_equal "ruflet.yml", builder.send(:ruflet_config_path)
        assert_equal "https://yml.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
      end
    end
  end

  private

  class RecordingBuilder < DummyBuilder
    attr_reader :calls
  end

  def builder_for(dir, config: {}, prepared: true, flutter_ok: true)
    builder = RecordingBuilder.new
    calls = {}
    builder.instance_variable_set(:@calls, calls)
    client = File.join(dir, "client")
    FileUtils.mkdir_p(File.join(client, "lib"))
    File.write(File.join(client, "lib", "main.server.dart"), "void main() {}\n")
    File.write(File.join(client, "lib", "main.self.dart"), "void main() {}\n")

    builder.define_singleton_method(:ensure_flutter_client_dir) { |verbose: false| client }
    builder.define_singleton_method(:load_ruflet_config) { config }
    builder.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| { flutter: "flutter", dart: "dart", env: {} } }
    builder.define_singleton_method(:build_tool_env) { |env, *_args| env }
    builder.define_singleton_method(:prepare_flutter_client) do |_dir, platform:, **_opts|
      calls[:prepared_platform] = platform
      prepared
    end
    builder.define_singleton_method(:system) do |_env, *command, **_opts|
      (calls[:flutter] ||= []) << command
      flutter_ok
    end
    builder
  end

  def installer_for(dir, flutter_ok: true)
    builder = builder_for(dir, flutter_ok: flutter_ok)
    builder.define_singleton_method(:install_tool_env) { |env, *_args| env }
    builder.define_singleton_method(:sync_built_outputs_for_install) { |*_args, **_opts| true }
    builder
  end

  def with_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def in_project
    Dir.mktmpdir { |dir| Dir.chdir(dir) { yield dir } }
  end
end
