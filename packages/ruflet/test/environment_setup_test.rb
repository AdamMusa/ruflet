# frozen_string_literal: true

require_relative "test_helper"

class RufletCliEnvironmentSetupTest < Minitest::Test
  class Harness
    include Ruflet::CLI::FlutterSdk
    include Ruflet::CLI::EnvironmentSetup

    attr_accessor :fake_host, :fake_windows, :fake_macos, :available_commands,
                  :installed_packages, :present_overrides

    def initialize(host:, windows: false, macos: false, commands: [])
      @fake_host = host
      @fake_windows = windows
      @fake_macos = macos
      @available_commands = commands
      @installed_packages = []
      @present_overrides = {}
    end

    def flutter_host
      @fake_host
    end

    def windows_host?
      @fake_windows
    end

    def macos_host?
      @fake_macos
    end

    def which_command(name)
      @available_commands.include?(name) ? "/usr/bin/#{name}" : nil
    end

    def tool_present?(tool)
      return @present_overrides[tool.name] if @present_overrides.key?(tool.name)

      tool.probe ? @available_commands.include?(tool.probe) : false
    end

    def run_privileged_command(*command, verbose: false)
      @installed_packages << command
      true
    end

    def sudo_prefix
      []
    end

    # Silence output during tests.
    def puts(*); end
    def warn(*); end
  end

  def test_detects_apt_on_debian_family
    harness = Harness.new(host: "linux", commands: %w[apt-get])
    assert_equal :apt, harness.system_package_manager[:id]
  end

  def test_detects_dnf_on_fedora
    harness = Harness.new(host: "linux", commands: %w[dnf])
    assert_equal :dnf, harness.system_package_manager[:id]
  end

  def test_detects_pacman_on_arch
    harness = Harness.new(host: "linux", commands: %w[pacman])
    assert_equal :pacman, harness.system_package_manager[:id]
  end

  def test_detects_zypper_on_opensuse
    harness = Harness.new(host: "linux", commands: %w[zypper])
    assert_equal :zypper, harness.system_package_manager[:id]
  end

  def test_detects_winget_on_windows
    harness = Harness.new(host: "windows", windows: true, commands: %w[winget])
    assert_equal :winget, harness.system_package_manager[:id]
  end

  def test_detects_brew_on_macos
    harness = Harness.new(host: "macos_arm64", macos: true, commands: %w[brew])
    assert_equal :brew, harness.system_package_manager[:id]
  end

  def test_linux_requires_desktop_toolchain
    harness = Harness.new(host: "linux", commands: %w[apt-get])
    names = harness.required_system_tools.map(&:name)

    %w[git curl unzip xz zip clang cmake ninja pkg-config].each do |tool|
      assert_includes names, tool
    end
    assert_includes names, "GTK 3 headers"
  end

  def test_windows_requires_git_and_vs_build_tools
    harness = Harness.new(host: "windows", windows: true, commands: %w[winget])
    names = harness.required_system_tools.map(&:name)

    assert_includes names, "git"
    assert_includes names, "Visual Studio Build Tools"
  end

  def test_macos_requires_xcode_clt_and_cocoapods
    harness = Harness.new(host: "macos_arm64", macos: true, commands: %w[brew])
    names = harness.required_system_tools.map(&:name)

    assert_includes names, "Xcode Command Line Tools"
    assert_includes names, "CocoaPods"
  end

  def test_fix_installs_missing_packages_via_apt
    harness = Harness.new(host: "linux", commands: %w[apt-get git curl unzip xz zip clang cmake pkg-config])
    harness.present_overrides["GTK 3 headers"] = false
    # ninja missing -> should be installed; mark everything else present after install
    harness.present_overrides["ninja"] = false

    def harness.tool_present?(tool)
      # After install_system_packages ran, report success.
      return true if @installed_packages.any?

      super
    end

    issues = harness.environment_setup!(fix: true)
    assert_empty issues
    install_call = harness.installed_packages.find { |cmd| cmd.include?("install") }
    refute_nil install_call
    assert_includes install_call, "ninja-build"
    assert_includes install_call, "libgtk-3-dev"
  end

  def test_fix_maps_packages_per_distro
    {
      %w[dnf] => %w[ninja-build gtk3-devel],
      %w[pacman] => %w[ninja gtk3],
      %w[zypper] => %w[ninja gtk3-devel]
    }.each do |commands, expected_packages|
      harness = Harness.new(host: "linux", commands: commands + %w[git curl unzip xz zip clang cmake pkg-config])
      harness.present_overrides["GTK 3 headers"] = false
      harness.present_overrides["ninja"] = false

      def harness.tool_present?(tool)
        return true if @installed_packages.any?

        super
      end

      harness.environment_setup!(fix: true)
      install_call = harness.installed_packages.find do |cmd|
        expected_packages.any? { |package| cmd.include?(package) }
      end
      refute_nil install_call, "no install for #{commands}"
      expected_packages.each do |package|
        assert_includes install_call, package, "#{commands} should install #{package}"
      end
    end
  end

  def test_without_fix_reports_missing_tools_as_issues
    harness = Harness.new(host: "linux", commands: %w[apt-get])
    issues = harness.environment_setup!(fix: false)

    refute_empty issues
    assert(issues.any? { |issue| issue.include?("git") })
    assert_empty harness.installed_packages
  end

  def test_manual_steps_are_not_auto_installed
    harness = Harness.new(host: "windows", windows: true, commands: %w[winget git])
    issues = harness.environment_setup!(fix: true)

    assert(issues.any? { |issue| issue.include?("Visual Studio Build Tools") })
    refute(harness.installed_packages.flatten.join(" ").include?("VisualStudio"),
           "VS Build Tools must not be auto-installed")
  end

  def test_unsupported_host_reports_clear_message
    harness = Harness.new(host: nil)
    def harness.machine_arch = "aarch64"
    def harness.unsupported_host_message_for_test = send(:unsupported_host_message)

    issues = harness.environment_setup!(fix: true)
    refute_empty issues
  end

  def test_all_clear_returns_no_issues
    harness = Harness.new(
      host: "linux",
      commands: %w[apt-get git curl unzip xz zip clang cmake ninja pkg-config]
    )
    harness.present_overrides["GTK 3 headers"] = true

    assert_empty harness.environment_setup!(fix: false)
    assert_empty harness.installed_packages
  end

  def test_flutter_host_rejects_linux_arm
    harness = Object.new.extend(Ruflet::CLI::FlutterSdk)
    def harness.machine_arch = "aarch64"

    stubbed = RbConfig::CONFIG["host_os"]
    if stubbed.match?(/linux/i)
      assert_nil harness.send(:flutter_host)
    else
      # On non-Linux dev machines the host resolution is unaffected.
      refute_nil harness.send(:flutter_host)
    end
  end
end
