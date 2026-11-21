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
      # Flutter's spelling keeps its name (logs, .ruflet-runtime.json and the
      # --full cache key say "appbundle", as before); the checks treat it as
      # aab (test_appbundle_gets_the_checks_aab_gets).
      "appbundle" => [["build", "appbundle"], "appbundle"],
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
      test = self # the stub runs with the runner as self
      builder.define_singleton_method(:export_platform_build_outputs) { |*_args, **_opts| test.flunk("nothing to export") }
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
  # anyway, signing with whatever key.properties an earlier build left in the
  # client (or the debug key). Now it stops the build before anything else is
  # written. The error names where the partial setup came from: once one
  # RUFLET_ANDROID_* variable is set, the environment replaces
  # android/key.properties, even a complete one.
  def test_partial_android_signing_fails_the_build
    complete = "storeFile=release.jks\nstorePassword=s\nkeyAlias=a\nkeyPassword=k\n"
    partial_env = { "RUFLET_ANDROID_KEYSTORE" => "release.jks", "RUFLET_ANDROID_KEYSTORE_PASSWORD" => nil,
                    "RUFLET_ANDROID_KEY_ALIAS" => nil, "RUFLET_ANDROID_KEY_PASSWORD" => nil }
    no_env = partial_env.transform_values { nil }
    [
      ["a partial environment", partial_env, nil, "the RUFLET_ANDROID_* environment"],
      ["a leftover variable beside a complete android/key.properties", partial_env, complete,
       "the RUFLET_ANDROID_* environment"],
      ["a partial android/key.properties", no_env, "storeFile=release.jks\n", "android/key.properties"]
    ].each do |label, env, project_properties, source|
      in_project do |dir|
        if project_properties
          FileUtils.mkdir_p("android")
          File.write(File.join("android", "key.properties"), project_properties)
        end
        client = File.join(dir, "client")
        FileUtils.mkdir_p(File.join(client, "android"))
        stale = File.join(client, "android", "key.properties")
        File.write(stale, "storeFile=/old/release.jks\n")

        builder = DummyBuilder.new
        builder.define_singleton_method(:refresh_managed_client_template_files) { |*_args, **_opts| true }
        builder.define_singleton_method(:remove_native_apple_renderer_integration) { |*_args, **_opts| true }
        builder.define_singleton_method(:sync_client_metadata) { |*_args, **_opts| nil }
        builder.define_singleton_method(:apply_native_service_permissions) { |*_args| nil }
        test = self # the stub runs with the runner as self
        builder.define_singleton_method(:configure_client_runtime_mode) { |*_args, **_opts| test.flunk("#{label}: must stop at the signing error") }

        with_env(env) do
          _out, err = capture_io do
            refute builder.send(:prepare_flutter_client, client, platform: "apk", tools: { env: {}, flutter: "flutter" }, config: {}), label
          end
          # Each case supplies only storeFile.
          assert_match(/\Abuild config error: Android signing from \S*#{Regexp.escape(source)} is missing storePassword, keyAlias, keyPassword\n/, err, label)
          assert_includes err, "Set them in android/key.properties or the matching RUFLET_ANDROID_* variables.", label
        end
        assert_equal "storeFile=/old/release.jks\n", File.read(stale), label
      end
    end
  end

  # `appbundle` is Flutter's name for `aab`. The identity check, the package
  # rename and the stale-asset clearing only recognised `aab`, so an
  # appbundle kept the template's com.example.ruflet_client application id
  # (and skipped the check that a mobile build names its app).
  def test_appbundle_gets_the_checks_aab_gets
    builder = DummyBuilder.new
    unnamed = { mobile_identity_errors: ["app.package_name"] }
    %w[aab appbundle].each do |target|
      _out, err = capture_io { refute builder.send(:validate_mobile_app_identity, unnamed, platform: target), target }
      assert_includes err, "ruflet.yaml must define app.package_name", target

      renames = []
      builder.define_singleton_method(:run_external_command) do |_env, *command, **_opts|
        renames << command
        true
      end
      capture_io do
        assert builder.send(:apply_mobile_package_name, "/client", { android_application_id: "com.acme.shop" },
                            platform: target, tools: { env: {}, dart: "dart" }), target
      end
      assert_equal [["dart", "run", "change_app_package_name:main", "com.acme.shop", "--android"]], renames, target

      Dir.mktmpdir do |client|
        stale = File.join(client, "build", "app", "intermediates", "assets")
        FileUtils.mkdir_p(stale)
        builder.send(:clear_stale_platform_outputs, client, target)
        refute Dir.exist?(stale), target
      end
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

  # Every other id maps as it did before #84. old_rule is the rule
  # install_platform_for_device replaced.
  def test_other_device_ids_map_as_before
    old_rule = lambda do |device_id|
      next "android" if device_id.include?("emulator-") || device_id.match?(/\A[a-z0-9._:-]+\z/i) && device_id != "macos" && device_id != "chrome" && !device_id.include?("-")
      next "ios" if device_id.match?(/\A[0-9A-F-]{8,}\z/i)
      next "macos" if device_id == "macos"
      next "web" if device_id == "chrome"

      "inferred"
    end
    builder = DummyBuilder.new
    builder.define_singleton_method(:inferred_install_platform) { "inferred" }
    [
      "emulator-5554", " emulator-5554", "R58M123ABCD", "0123456789ABCDEF", "192.168.1.20:5555",
      "00008030-001A2D3C0E12802E", "6B29FC40-CA47-1067-B31D-00DD010662DA", "0123-4567", "macos", "chrome",
      " linux", "iPhone-15", "ZY22-4F7Q", "my phone", ""
    ].each do |device_id|
      assert_equal old_rule.call(device_id), builder.send(:install_platform_for_device, device_id), device_id.inspect
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
      File.write("ruflet.yml", "app:\n  backend_url: https://yml.example.test\n")
      with_env("RUFLET_CONFIG" => nil) do
        assert_equal "https://yml.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
        File.write("ruflet.yaml", "app:\n  backend_url: https://yaml.example.test\n")
        assert_equal "https://yaml.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
      end

      File.write("custom.yaml", "app:\n  backend_url: https://custom.example.test\n")
      with_env("RUFLET_CONFIG" => "custom.yaml") do
        assert_equal "https://custom.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
      end

      # A RUFLET_CONFIG naming a missing file loads ruflet.yml.
      File.delete("ruflet.yaml")
      with_env("RUFLET_CONFIG" => "missing.yaml") do
        assert_equal "https://yml.example.test", builder.send(:load_ruflet_config).dig("app", "backend_url")
      end
    end
  end

  # With RUFLET_CONFIG naming a missing file, asset configuration resolves the
  # assets ruflet.yml declares against the project directory, the directory
  # ruflet.yml is in: resolving that file separately from load_ruflet_config
  # gives the same directory, so the two cannot disagree here.
  def test_assets_ruflet_yml_declares_are_configured_when_ruflet_config_names_a_missing_file
    in_project do |dir|
      FileUtils.mkdir_p("art")
      File.binwrite(File.join("art", "icon.png"), "png")
      File.write("ruflet.yml", "assets:\n  icon_launcher: art/icon.png\n")
      client = File.join(dir, "client")
      FileUtils.mkdir_p(client)
      File.write(File.join(client, "pubspec.yaml"), "name: client\n")

      builder = DummyBuilder.new
      flags = with_env("RUFLET_CONFIG" => "missing.yaml") do
        builder.send(:apply_build_config, client, builder.send(:load_ruflet_config))
      end

      assert flags[:has_icon], flags.inspect
      assert_includes File.read(File.join(client, "pubspec.yaml")), "icon.png"
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
