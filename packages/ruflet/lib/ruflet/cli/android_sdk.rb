# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

module Ruflet
  module CLI
    # Provisions the Android toolchain so `ruflet build apk|aab|android`
    # works on a fresh machine:
    #
    #   * a JDK (Gradle itself is bootstrapped by the project's Gradle
    #     wrapper, but the wrapper needs Java)
    #   * the Android SDK command-line tools
    #   * platform-tools / a platform / build-tools via sdkmanager
    #   * accepted SDK licenses
    #
    # An existing SDK (ANDROID_HOME, ANDROID_SDK_ROOT, or the standard
    # per-OS install location) is always preferred; otherwise a Ruflet-managed
    # SDK is created under ~/.ruflet/android-sdk.
    module AndroidSdk
      CMDLINE_TOOLS_VERSION = "11076708"
      CMDLINE_TOOLS_BASE = "https://dl.google.com/android/repository".freeze
      ANDROID_PLATFORM = "android-35"
      ANDROID_BUILD_TOOLS = "35.0.0"
      MINIMUM_JAVA_MAJOR = 17

      JDK_PACKAGES = {
        apt: "openjdk-17-jdk",
        dnf: "java-17-openjdk-devel",
        pacman: "jdk17-openjdk",
        zypper: "java-17-openjdk-devel",
        apk: "openjdk17",
        brew: "openjdk@17",
        winget: "EclipseAdoptium.Temurin.17.JDK",
        choco: "temurin17"
      }.freeze

      def android_environment_setup!(fix: false, verbose: false)
        issues = []

        java = ensure_java!(fix: fix, verbose: verbose)
        if java
          puts "  Java: #{java[:version]} (#{java[:path]})"
        else
          issues << "missing JDK #{MINIMUM_JAVA_MAJOR}+"
          warn "  Java: missing — Android builds need a JDK (Gradle wrapper requirement)."
          warn "    #{jdk_install_hint}"
          return issues unless fix
        end

        sdk_root = detect_android_sdk_root
        if sdk_root
          puts "  Android SDK: #{sdk_root}"
        elsif fix
          unless java
            warn "  Android SDK: skipped (sdkmanager needs Java)"
            return issues
          end
          sdk_root = install_managed_android_sdk(java, verbose: verbose)
          unless sdk_root
            issues << "Android SDK install failed"
            warn "  Android SDK: install failed"
            return issues
          end
          puts "  Android SDK: #{sdk_root} (installed)"
        else
          issues << "missing Android SDK"
          warn "  Android SDK: missing — run `ruflet doctor --fix` to install it under #{managed_android_sdk_root}."
          return issues
        end

        if fix && java
          ensure_android_packages(sdk_root, java, verbose: verbose)
          accept_android_licenses(sdk_root, java, verbose: verbose)
        end

        issues
      end

      # Environment for invoking Flutter/Gradle Android builds.
      def android_build_env(env)
        merged = env.dup
        sdk_root = detect_android_sdk_root
        if sdk_root
          merged["ANDROID_HOME"] ||= sdk_root
          merged["ANDROID_SDK_ROOT"] ||= sdk_root
          platform_tools = File.join(sdk_root, "platform-tools")
          if Dir.exist?(platform_tools)
            merged["PATH"] = "#{platform_tools}#{File::PATH_SEPARATOR}#{merged.fetch('PATH', ENV.fetch('PATH', ''))}"
          end
        end
        java_home = detect_java_home
        merged["JAVA_HOME"] ||= java_home if java_home
        merged
      end

      def detect_android_sdk_root
        candidates = [
          ENV["ANDROID_HOME"],
          ENV["ANDROID_SDK_ROOT"],
          default_android_sdk_location,
          managed_android_sdk_root
        ]
        candidates.compact.find { |root| android_sdk_present?(root) }
      end

      def managed_android_sdk_root
        File.join(Dir.home, ".ruflet", "android-sdk")
      end

      private

      def android_sdk_present?(root)
        return false if root.to_s.strip.empty?

        Dir.exist?(File.join(root, "platform-tools")) ||
          Dir.exist?(File.join(root, "cmdline-tools")) ||
          Dir.exist?(File.join(root, "platforms"))
      end

      def default_android_sdk_location
        if windows_host?
          local = ENV["LOCALAPPDATA"].to_s
          return File.join(local, "Android", "Sdk") unless local.empty?

          nil
        elsif macos_host?
          File.join(Dir.home, "Library", "Android", "sdk")
        else
          File.join(Dir.home, "Android", "Sdk")
        end
      end

      def ensure_java!(fix:, verbose: false)
        java = current_java_info
        return java if java && java[:major] >= MINIMUM_JAVA_MAJOR

        return nil unless fix

        manager = system_package_manager
        package = manager && JDK_PACKAGES[manager[:id]]
        return nil unless package

        if manager[:id] == :winget
          run_privileged_command(*manager[:install], package, verbose: verbose)
        else
          run_privileged_command(*manager[:install], package, verbose: verbose)
        end
        current_java_info
      end

      def current_java_info
        java = which_command("java") || bundled_java_candidate
        return nil unless java

        output, status = Open3.capture2e(java, "-version")
        return nil unless status.success?

        major = parse_java_major(output)
        return nil unless major

        { path: java, major: major, version: output.lines.first.to_s.strip }
      rescue StandardError
        nil
      end

      def bundled_java_candidate
        if macos_host?
          brew_java = "/opt/homebrew/opt/openjdk@17/bin/java"
          return brew_java if File.executable?(brew_java)
        end
        nil
      end

      def parse_java_major(output)
        match = output[/version "(\d+)(?:\.(\d+))?/, 1]
        return nil unless match

        major = match.to_i
        # "1.8" style versions report the major in the second group.
        major = output[/version "1\.(\d+)/, 1].to_i if major == 1
        major
      end

      def detect_java_home
        if macos_host?
          output, status = Open3.capture2e("/usr/libexec/java_home", "-v", MINIMUM_JAVA_MAJOR.to_s)
          return output.strip if status.success? && !output.strip.empty?
        end

        java = which_command("java")
        return nil unless java

        resolved = File.realpath(java) rescue java
        home = File.expand_path("../..", resolved)
        File.directory?(File.join(home, "bin")) ? home : nil
      end

      def install_managed_android_sdk(java, verbose: false)
        sdk_root = managed_android_sdk_root
        tools_dir = File.join(sdk_root, "cmdline-tools", "latest")
        return sdk_root if File.executable?(sdkmanager_bin(sdk_root))

        archive_name = "commandlinetools-#{cmdline_tools_os}-#{CMDLINE_TOOLS_VERSION}_latest.zip"
        FileUtils.mkdir_p(sdk_root)
        Dir.mktmpdir("ruflet-android-") do |tmp|
          archive = File.join(tmp, archive_name)
          puts "  Downloading Android command-line tools (#{archive_name})"
          download_file("#{CMDLINE_TOOLS_BASE}/#{archive_name}", archive)
          extract_archive(archive, tmp)
          extracted = File.join(tmp, "cmdline-tools")
          raise "cmdline-tools missing from archive" unless Dir.exist?(extracted)

          FileUtils.rm_rf(tools_dir)
          FileUtils.mkdir_p(File.dirname(tools_dir))
          FileUtils.mv(extracted, tools_dir)
        end

        File.executable?(sdkmanager_bin(sdk_root)) ? sdk_root : nil
      rescue StandardError => e
        warn "  Android SDK download failed: #{e.class}: #{e.message}"
        nil
      end

      def cmdline_tools_os
        return "win" if windows_host?
        return "mac" if macos_host?

        "linux"
      end

      def sdkmanager_bin(sdk_root)
        name = windows_host? ? "sdkmanager.bat" : "sdkmanager"
        File.join(sdk_root, "cmdline-tools", "latest", "bin", name)
      end

      def ensure_android_packages(sdk_root, java, verbose: false)
        sdkmanager = sdkmanager_bin(sdk_root)
        return unless File.executable?(sdkmanager)

        packages = ["platform-tools", "platforms;#{ANDROID_PLATFORM}", "build-tools;#{ANDROID_BUILD_TOOLS}"]
        missing = packages.reject { |package| android_package_installed?(sdk_root, package) }
        return if missing.empty?

        puts "  Installing Android packages: #{missing.join(', ')}"
        env = sdkmanager_env(java)
        # sdkmanager downloads sizeable platform/build-tool archives; stream so
        # the install reports progress instead of appearing to hang.
        system(env, sdkmanager, "--sdk_root=#{sdk_root}", *missing, out: $stdout, err: $stderr)
      end

      def android_package_installed?(sdk_root, package)
        case package
        when "platform-tools"
          Dir.exist?(File.join(sdk_root, "platform-tools"))
        when /\Aplatforms;(.+)\z/
          Dir.exist?(File.join(sdk_root, "platforms", Regexp.last_match(1)))
        when /\Abuild-tools;(.+)\z/
          Dir.exist?(File.join(sdk_root, "build-tools", Regexp.last_match(1)))
        else
          false
        end
      end

      def accept_android_licenses(sdk_root, java, verbose: false)
        sdkmanager = sdkmanager_bin(sdk_root)
        return unless File.executable?(sdkmanager)

        puts "  Accepting Android SDK licenses"
        env = sdkmanager_env(java)
        Open3.popen2e(env, sdkmanager, "--sdk_root=#{sdk_root}", "--licenses") do |stdin, stdout, wait|
          begin
            stdin.write("y\n" * 64)
            stdin.close
          rescue Errno::EPIPE
            nil
          end
          stdout.each_line { |line| puts line if verbose }
          wait.value
        end
      rescue StandardError => e
        warn "  License acceptance failed: #{e.class}: #{e.message}"
      end

      def sdkmanager_env(java)
        env = {}
        java_home = detect_java_home
        env["JAVA_HOME"] = java_home if java_home
        if java && java[:path]
          env["PATH"] = "#{File.dirname(java[:path])}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}"
        end
        env
      end

      def jdk_install_hint
        manager = system_package_manager
        package = manager && JDK_PACKAGES[manager[:id]]
        return "#{(sudo_prefix + manager[:install]).join(' ')} #{package}" if package

        "install a JDK #{MINIMUM_JAVA_MAJOR}+ (e.g. Temurin: https://adoptium.net)"
      end
    end
  end
end
