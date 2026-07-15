# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class RufletCliAndroidSdkTest < Minitest::Test
  class Harness
    include Ruflet::CLI::FlutterSdk
    include Ruflet::CLI::EnvironmentSetup
    include Ruflet::CLI::AndroidSdk

    attr_accessor :fake_windows, :fake_macos, :available_commands, :fake_home,
                  :fake_manager, :installed

    def initialize(home:, windows: false, macos: false, commands: [], manager: nil)
      @fake_home = home
      @fake_windows = windows
      @fake_macos = macos
      @available_commands = commands
      @fake_manager = manager
      @installed = []
    end

    def windows_host? = @fake_windows
    def macos_host? = @fake_macos

    def which_command(name)
      @available_commands.include?(name) ? "/usr/bin/#{name}" : nil
    end

    def system_package_manager = @fake_manager

    def run_privileged_command(*command, verbose: false)
      @installed << command
      true
    end

    def sudo_prefix = []

    def managed_android_sdk_root
      File.join(@fake_home, ".ruflet", "android-sdk")
    end

    def default_android_sdk_location
      File.join(@fake_home, "Android", "Sdk")
    end

    def detect_java_home = nil

    def puts(*); end
    def warn(*); end
  end

  def with_home
    Dir.mktmpdir("ruflet-android-test-") { |home| yield home }
  end

  def make_sdk(root)
    FileUtils.mkdir_p(File.join(root, "platform-tools"))
    root
  end

  def test_detects_sdk_from_android_home_env
    with_home do |home|
      custom = make_sdk(File.join(home, "custom-sdk"))
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => custom, "ANDROID_SDK_ROOT" => nil) do
        assert_equal custom, harness.detect_android_sdk_root
      end
    end
  end

  def test_detects_sdk_from_default_location
    with_home do |home|
      default = make_sdk(File.join(home, "Android", "Sdk"))
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        assert_equal default, harness.detect_android_sdk_root
      end
    end
  end

  def test_falls_back_to_managed_sdk_location
    with_home do |home|
      managed = make_sdk(File.join(home, ".ruflet", "android-sdk"))
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        assert_equal managed, harness.detect_android_sdk_root
      end
    end
  end

  def test_no_sdk_detected_on_clean_machine
    with_home do |home|
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        assert_nil harness.detect_android_sdk_root
      end
    end
  end

  def test_jdk_package_mapping_covers_all_managers
    %i[apt dnf pacman zypper apk brew winget choco].each do |manager|
      assert Ruflet::CLI::AndroidSdk::JDK_PACKAGES.key?(manager),
             "missing JDK package for #{manager}"
    end
  end

  def test_parse_java_major_handles_modern_and_legacy_formats
    harness = Harness.new(home: "/tmp")
    assert_equal 17, harness.send(:parse_java_major, 'openjdk version "17.0.9" 2023-10-17')
    assert_equal 21, harness.send(:parse_java_major, 'openjdk version "21" 2023-09-19')
    assert_equal 8, harness.send(:parse_java_major, 'java version "1.8.0_392"')
    assert_nil harness.send(:parse_java_major, "command not found")
  end

  def test_android_build_env_sets_sdk_variables
    with_home do |home|
      sdk = make_sdk(File.join(home, "Android", "Sdk"))
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        env = harness.android_build_env({ "PATH" => "/usr/bin" })

        assert_equal sdk, env["ANDROID_HOME"]
        assert_equal sdk, env["ANDROID_SDK_ROOT"]
        assert env["PATH"].start_with?(File.join(sdk, "platform-tools")),
               "platform-tools should be prepended to PATH"
      end
    end
  end

  def test_android_build_env_preserves_existing_android_home
    with_home do |home|
      make_sdk(File.join(home, "Android", "Sdk"))
      harness = Harness.new(home: home)
      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        env = harness.android_build_env({ "ANDROID_HOME" => "/explicit/sdk", "PATH" => "/usr/bin" })
        assert_equal "/explicit/sdk", env["ANDROID_HOME"]
      end
    end
  end

  def test_android_package_installed_checks
    with_home do |home|
      sdk = File.join(home, "sdk")
      FileUtils.mkdir_p(File.join(sdk, "platforms", "android-35"))
      FileUtils.mkdir_p(File.join(sdk, "build-tools", "35.0.0"))
      harness = Harness.new(home: home)

      assert harness.send(:android_package_installed?, sdk, "platforms;android-35")
      assert harness.send(:android_package_installed?, sdk, "build-tools;35.0.0")
      refute harness.send(:android_package_installed?, sdk, "platform-tools")
      refute harness.send(:android_package_installed?, sdk, "platforms;android-34")
    end
  end

  def test_missing_jdk_reported_without_fix
    with_home do |home|
      harness = Harness.new(home: home, manager: { id: :apt, install: %w[apt-get install -y] })
      def harness.current_java_info = nil

      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        issues = harness.android_environment_setup!(fix: false)
        assert(issues.any? { |issue| issue.include?("JDK") })
        assert_empty harness.installed
      end
    end
  end

  def test_fix_installs_jdk_via_package_manager
    with_home do |home|
      harness = Harness.new(home: home, manager: { id: :apt, install: %w[apt-get install -y] })
      attempts = []
      harness.define_singleton_method(:current_java_info) do
        attempts << :probe
        attempts.length > 1 ? { path: "/usr/bin/java", major: 17, version: "17" } : nil
      end
      harness.define_singleton_method(:install_managed_android_sdk) { |*| nil }

      with_env("ANDROID_HOME" => nil, "ANDROID_SDK_ROOT" => nil) do
        harness.android_environment_setup!(fix: true)
      end

      jdk_call = harness.installed.find { |cmd| cmd.include?("openjdk-17-jdk") }
      refute_nil jdk_call, "JDK should be installed via apt"
    end
  end

  def test_sdkmanager_path_per_os
    unix = Harness.new(home: "/tmp")
    assert unix.send(:sdkmanager_bin, "/sdk").end_with?("bin/sdkmanager")

    win = Harness.new(home: "/tmp", windows: true)
    assert win.send(:sdkmanager_bin, "/sdk").end_with?("sdkmanager.bat")
  end

  def test_cmdline_tools_os_naming
    assert_equal "linux", Harness.new(home: "/tmp").send(:cmdline_tools_os)
    assert_equal "mac", Harness.new(home: "/tmp", macos: true).send(:cmdline_tools_os)
    assert_equal "win", Harness.new(home: "/tmp", windows: true).send(:cmdline_tools_os)
  end

  private

  def with_env(overrides)
    saved = {}
    overrides.each do |key, value|
      saved[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
