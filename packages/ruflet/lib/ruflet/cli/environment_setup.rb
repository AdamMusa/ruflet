# frozen_string_literal: true

require "rbconfig"

module Ruflet
  module CLI
    # Provisions the host so `ruflet build` can run: checks (and with
    # `ruflet doctor --fix`, installs) the system tools Flutter requires.
    #
    # Coverage:
    #   Linux   apt (Ubuntu, Debian, Kali, Mint), dnf (Fedora, RHEL),
    #           pacman (Arch, Omarchy, Manjaro), zypper (openSUSE)
    #   macOS   Homebrew where available, plus Xcode Command Line Tools and
    #           CocoaPods guidance
    #   Windows winget or Chocolatey
    #
    # Anything that cannot be installed unattended (Xcode CLT, Visual Studio
    # Build Tools) is reported with the exact command the developer must run.
    module EnvironmentSetup
      Tool = Struct.new(:name, :probe, :purpose, :packages, :manual_hint, keyword_init: true)

      LINUX_PACKAGE_MANAGERS = [
        { id: :apt, probe: "apt-get", install: %w[apt-get install -y], update: %w[apt-get update] },
        { id: :dnf, probe: "dnf", install: %w[dnf install -y], update: nil },
        { id: :pacman, probe: "pacman", install: %w[pacman -S --noconfirm --needed], update: nil },
        { id: :zypper, probe: "zypper", install: %w[zypper --non-interactive install], update: nil },
        { id: :apk, probe: "apk", install: %w[apk add], update: nil }
      ].freeze

      def environment_setup!(fix: false, verbose: false)
        issues = []
        tools = required_system_tools

        unless flutter_host
          issues << unsupported_host_message
          warn "  System: #{unsupported_host_message}"
          return issues
        end

        manager = system_package_manager
        missing = tools.reject { |tool| tool_present?(tool) }

        if missing.empty?
          puts "  System tools: ok (#{tools.map(&:name).join(', ')})"
          return issues
        end

        puts "  System tools missing: #{missing.map(&:name).join(', ')}"

        unless fix
          missing.each { |tool| warn "    #{tool.name}: #{manual_hint_for(tool, manager)}" }
          warn "  Run `ruflet doctor --fix` to install them."
          return missing.map { |tool| "missing #{tool.name}" }
        end

        auto, manual = missing.partition { |tool| installable?(tool, manager) }

        if auto.any?
          if manager
            install_system_packages(manager, auto, verbose: verbose)
          end
          still_missing = auto.reject { |tool| tool_present?(tool) }
          still_missing.each do |tool|
            issues << "missing #{tool.name}"
            warn "    #{tool.name}: install failed — #{manual_hint_for(tool, manager)}"
          end
          installed = auto - still_missing
          puts "  Installed: #{installed.map(&:name).join(', ')}" if installed.any?
        end

        manual.each do |tool|
          issues << "missing #{tool.name}"
          warn "    #{tool.name}: requires a manual step — #{manual_hint_for(tool, manager)}"
        end

        issues
      end

      def required_system_tools
        case flutter_host
        when "linux" then linux_required_tools
        when "macos", "macos_arm64" then macos_required_tools
        when "windows" then windows_required_tools
        else []
        end
      end

      def system_package_manager
        if windows_host?
          return { id: :winget, install: %w[winget install --accept-source-agreements --accept-package-agreements -e --id] } if which_command("winget")
          return { id: :choco, install: %w[choco install -y] } if which_command("choco")
          return nil
        end

        if macos_host?
          return { id: :brew, install: %w[brew install] } if which_command("brew")
          return nil
        end

        LINUX_PACKAGE_MANAGERS.each do |manager|
          next unless which_command(manager[:probe])

          return manager
        end
        nil
      end

      private

      def macos_host?
        RbConfig::CONFIG["host_os"].match?(/darwin/i)
      end

      def linux_required_tools
        [
          Tool.new(name: "git", probe: "git", purpose: "required by the Flutter tool itself",
                   packages: { apt: "git", dnf: "git", pacman: "git", zypper: "git", apk: "git" }),
          Tool.new(name: "curl", probe: "curl", purpose: "SDK downloads",
                   packages: { apt: "curl", dnf: "curl", pacman: "curl", zypper: "curl", apk: "curl" }),
          Tool.new(name: "unzip", probe: "unzip", purpose: "extracting Flutter artifacts",
                   packages: { apt: "unzip", dnf: "unzip", pacman: "unzip", zypper: "unzip", apk: "unzip" }),
          Tool.new(name: "xz", probe: "xz", purpose: "extracting the Flutter SDK (.tar.xz)",
                   packages: { apt: "xz-utils", dnf: "xz", pacman: "xz", zypper: "xz", apk: "xz" }),
          Tool.new(name: "zip", probe: "zip", purpose: "packaging app bundles",
                   packages: { apt: "zip", dnf: "zip", pacman: "zip", zypper: "zip", apk: "zip" }),
          Tool.new(name: "clang", probe: "clang", purpose: "Linux desktop builds",
                   packages: { apt: "clang", dnf: "clang", pacman: "clang", zypper: "clang", apk: "clang" }),
          Tool.new(name: "cmake", probe: "cmake", purpose: "Linux desktop builds",
                   packages: { apt: "cmake", dnf: "cmake", pacman: "cmake", zypper: "cmake", apk: "cmake" }),
          Tool.new(name: "ninja", probe: "ninja", purpose: "Linux desktop builds",
                   packages: { apt: "ninja-build", dnf: "ninja-build", pacman: "ninja", zypper: "ninja", apk: "ninja" }),
          Tool.new(name: "pkg-config", probe: "pkg-config", purpose: "Linux desktop builds",
                   packages: { apt: "pkg-config", dnf: "pkgconf-pkg-config", pacman: "pkgconf", zypper: "pkg-config", apk: "pkgconf" }),
          Tool.new(name: "GTK 3 headers", probe: nil, purpose: "Linux desktop builds",
                   packages: { apt: "libgtk-3-dev", dnf: "gtk3-devel", pacman: "gtk3", zypper: "gtk3-devel", apk: "gtk+3.0-dev" })
        ]
      end

      def macos_required_tools
        [
          Tool.new(name: "git", probe: "git", purpose: "required by the Flutter tool itself",
                   packages: { brew: "git" },
                   manual_hint: "install Xcode Command Line Tools: xcode-select --install"),
          Tool.new(name: "curl", probe: "curl", purpose: "SDK downloads", packages: { brew: "curl" }),
          Tool.new(name: "unzip", probe: "unzip", purpose: "extracting Flutter artifacts", packages: { brew: "unzip" }),
          Tool.new(name: "Xcode Command Line Tools", probe: nil, purpose: "macOS/iOS builds",
                   packages: {},
                   manual_hint: "run `xcode-select --install` (or install Xcode from the App Store)"),
          Tool.new(name: "CocoaPods", probe: "pod", purpose: "macOS/iOS plugin dependencies",
                   packages: { brew: "cocoapods" },
                   manual_hint: "run `brew install cocoapods` or `sudo gem install cocoapods`")
        ]
      end

      def windows_required_tools
        [
          Tool.new(name: "git", probe: "git", purpose: "required by the Flutter tool itself",
                   packages: { winget: "Git.Git", choco: "git" }),
          Tool.new(name: "Visual Studio Build Tools", probe: nil, purpose: "Windows desktop builds",
                   packages: {},
                   manual_hint: "winget install --id Microsoft.VisualStudio.2022.BuildTools (select the " \
                                "\"Desktop development with C++\" workload)")
        ]
      end

      def tool_present?(tool)
        case tool.name
        when "GTK 3 headers"
          return true if which_command("pkg-config") &&
                         system("pkg-config", "--exists", "gtk+-3.0", out: File::NULL, err: File::NULL)

          false
        when "Xcode Command Line Tools"
          system("xcode-select", "-p", out: File::NULL, err: File::NULL)
        else
          tool.probe ? !which_command(tool.probe).nil? : false
        end
      end

      def installable?(tool, manager)
        return false unless manager

        tool.packages.key?(manager[:id])
      end

      def manual_hint_for(tool, manager)
        return tool.manual_hint if tool.manual_hint && !installable?(tool, manager)
        return "no supported package manager found; install #{tool.name} manually" unless manager

        package = tool.packages[manager[:id]]
        return tool.manual_hint || "install #{tool.name} manually" unless package

        "#{(sudo_prefix + manager[:install]).join(' ')} #{package}"
      end

      def install_system_packages(manager, tools, verbose: false)
        packages = tools.map { |tool| tool.packages[manager[:id]] }.compact.uniq
        return if packages.empty?

        if manager[:update]
          run_privileged_command(*manager[:update], verbose: verbose)
        end

        if manager[:id] == :winget
          # winget installs one id at a time.
          packages.each { |package| run_privileged_command(*manager[:install], package, verbose: verbose) }
        else
          run_privileged_command(*manager[:install], *packages, verbose: verbose)
        end
      end

      def run_privileged_command(*command, verbose: false)
        full = sudo_prefix + command
        puts "  $ #{full.join(' ')}"
        output = verbose ? $stdout : File::NULL
        system(*full, out: output, err: $stderr)
      end

      def sudo_prefix
        return [] if windows_host? || macos_host?
        return [] if Process.respond_to?(:uid) && Process.uid.zero?
        return ["sudo"] if which_command("sudo")

        []
      end

      def unsupported_host_message
        os = RbConfig::CONFIG["host_os"]
        if os.match?(/linux/i) && machine_arch.match?(/arm|aarch64/)
          "Flutter publishes no official Linux #{machine_arch} build; use an x64 machine " \
            "or build Flutter from source (https://github.com/flutter/flutter)."
        else
          "unsupported host platform: #{os}"
        end
      end
    end
  end
end
