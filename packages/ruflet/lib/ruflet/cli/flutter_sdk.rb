# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "rbconfig"
require "tmpdir"
require "uri"
require "yaml"
require_relative "verified_install"

module Ruflet
  module CLI
    module FlutterSdk
      RELEASES_BASE = "https://storage.googleapis.com/flutter_infra_release/releases".freeze
      DEFAULT_FLUTTER_CHANNEL = "stable".freeze
      # Written beside flutter/ when an SDK installed before installs were
      # marked complete fails `flutter --version` (see managed_flutter_sdk_complete?).
      INCOMPLETE_MARKER = ".ruflet-incomplete".freeze
      LEGACY_SDK_PROBE_SECONDS = 120

      def ensure_flutter!(command_name, client_dir: nil, auto_install: true)
        tools = flutter_tools(client_dir: client_dir, auto_install: auto_install)
        return tools if tools

        warn "Flutter is required for `ruflet #{command_name}` and FVM bootstrap failed."
        warn "Set RUFLET_FLUTTER_VERSION or add .fvmrc to the project."
        exit 1
      end

      def flutter_version_summary(tools)
        flutter_bin = tools[:flutter]
        env = tools[:env] || {}

        machine_output, status = Open3.capture2e(env, flutter_bin, "--version", "--machine")
        if status.success?
          parsed = JSON.parse(machine_output) rescue nil
          version = parsed && parsed["frameworkVersion"].to_s.strip
          channel = parsed && parsed["channel"].to_s.strip
          return [version, channel].reject(&:empty?).join(" ") unless version.to_s.empty?
        end

        text_output, text_status = Open3.capture2e(env, flutter_bin, "--version")
        return text_output.lines.first.to_s.strip if text_status.success?

        File.basename(flutter_bin.to_s)
      rescue StandardError
        File.basename(flutter_bin.to_s)
      end

      private

      def flutter_tools(client_dir: nil, auto_install: true)
        desired = desired_flutter_spec(client_dir: client_dir)

        # Environment and .fvmrc versions are intentional pins. Flutter's
        # generated .metadata revision only records which SDK created the
        # project; it must not force every build to download that old SDK.
        if %i[env fvmrc].include?(desired[:source])
          fvm_tools = flutter_tools_via_fvm(client_dir: client_dir, auto_install: auto_install)
          return fvm_tools if fvm_tools
        else
          system_tools = flutter_tools_via_system
          return system_tools if system_tools
        end

        managed_tools = flutter_tools_via_managed_sdk(client_dir: client_dir, auto_install: auto_install)
        return managed_tools if managed_tools

        nil
      end

      def flutter_tools_via_system
        flutter = which_command("flutter")
        return nil unless flutter

        tools_from_flutter_bin(flutter)
      end

      def flutter_tools_via_managed_sdk(client_dir: nil, auto_install: true)
        sdk_root =
          if auto_install
            ensure_flutter_sdk_downloaded(client_dir: client_dir)
          else
            # Without auto-install (plain `ruflet doctor`) nothing is
            # downloaded, but an SDK an earlier run installed still counts.
            installed_managed_flutter_sdk_root(client_dir: client_dir)
          end
        return nil unless sdk_root

        tools_from_flutter_bin(File.join(sdk_root, "bin", flutter_executable_name))
      end

      def flutter_tools_via_fvm(client_dir: nil, auto_install: true)
        version = desired_flutter_version(client_dir: client_dir)
        return nil if version.to_s.strip.empty?

        project_dir = fvm_project_dir(client_dir: client_dir)
        flutter = existing_fvm_flutter_bin(project_dir)
        return tools_from_flutter_bin(flutter) if flutter

        return nil unless auto_install

        fvm = ensure_fvm_available(client_dir: client_dir)
        return nil unless fvm
        FileUtils.mkdir_p(project_dir)
        fvmrc_path = File.join(project_dir, ".fvmrc")
        unless File.file?(fvmrc_path)
          File.write(fvmrc_path, "{\"flutter\":\"#{version}\"}\n")
        end

        system(fvm_env, fvm, "install", version.to_s, chdir: project_dir, out: File::NULL, err: File::NULL)
        system(fvm_env, fvm, "use", "--force", version.to_s, chdir: project_dir, out: File::NULL, err: File::NULL)

        flutter = flutter_bin_path(project_dir)
        return nil unless File.executable?(flutter)

        tools_from_flutter_bin(flutter)
      rescue StandardError => e
        warn "FVM bootstrap failed: #{e.class}: #{e.message}"
        nil
      end

      def ensure_fvm_available(client_dir: nil)
        fvm = which_command("fvm")
        return fvm if fvm

        dart = which_command("dart")
        unless dart
          sdk_root = ensure_flutter_sdk_downloaded(client_dir: client_dir)
          dart = sdk_root ? File.join(sdk_root, "bin", dart_executable_name) : nil
        end
        return nil unless dart && File.executable?(dart)

        system(dart, "pub", "global", "activate", "fvm", out: File::NULL, err: File::NULL)
        installed_fvm = File.join(pub_cache_bin_dir, fvm_executable_name)
        return installed_fvm if File.executable?(installed_fvm)

        which_command("fvm")
      end

      def fvm_env
        utf8_locale_env.merge("PATH" => "#{pub_cache_bin_dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}")
      end

      # CocoaPods aborts with "Unicode Normalization not appropriate for
      # ASCII-8BIT" when it inherits a non-UTF-8 locale, which takes the whole
      # iOS and macOS build with it. Hand the toolchain a UTF-8 locale unless
      # the environment already has one.
      def utf8_locale_env
        return {} if utf8_locale?(ENV["LC_ALL"]) || utf8_locale?(ENV["LANG"])

        { "LANG" => "en_US.UTF-8", "LC_ALL" => "en_US.UTF-8" }
      end

      def utf8_locale?(value)
        value.to_s.match?(/utf-?8/i)
      end

      def tools_from_flutter_bin(flutter_bin)
        return nil unless File.executable?(flutter_bin)

        bin_dir = File.dirname(flutter_bin)
        sdk_root = File.expand_path("..", bin_dir)
        dart = File.join(bin_dir, dart_executable_name)
        {
          flutter: flutter_bin,
          dart: (File.executable?(dart) ? dart : "dart"),
          env: utf8_locale_env.merge(
            "PATH" => "#{bin_dir}#{File::PATH_SEPARATOR}#{pub_cache_bin_dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}",
            "FLUTTER_ROOT" => sdk_root,
            "FVM_FLUTTER_SDK" => sdk_root
          )
        }
      end

      def ensure_flutter_sdk_downloaded(client_dir: nil)
        release_info =
          begin
            resolve_flutter_release(client_dir: client_dir)
          rescue StandardError
            # Offline: the release manifest is unreachable, but an SDK that
            # is already installed needs no download.
            installed = installed_managed_flutter_sdk_root(client_dir: client_dir)
            return installed if installed

            raise
          end
        return installed_managed_flutter_sdk_root(client_dir: client_dir) unless release_info

        release = release_info[:release]
        install_root = File.join(Dir.home, ".ruflet", "flutter", release.fetch("version"), release_info[:host])
        sdk_root = File.join(install_root, "flutter")
        return sdk_root if managed_flutter_sdk_complete?(install_root)

        pinned = %i[env fvmrc].include?(desired_flutter_spec(client_dir: client_dir)[:source])
        installed = install_managed_flutter_sdk(release, install_root, pinned: pinned)
        return installed if installed

        installed_flutter_sdk_after_failed_install(client_dir)
      rescue StandardError => e
        warn "Flutter auto-install failed: #{e.class}: #{e.message}"
        installed_flutter_sdk_after_failed_install(client_dir)
      end

      # A newer SDK that could not be installed must not cost the build the
      # SDK it already has (a pin still only accepts its own version).
      def installed_flutter_sdk_after_failed_install(client_dir)
        installed = installed_managed_flutter_sdk_root(client_dir: client_dir)
        warn "Using the Flutter SDK already installed at #{installed}" if installed
        installed
      end

      # Downloads the release archive, checks it against the sha256 Flutter's
      # release manifest lists for it, unpacks it beside install_root and
      # swaps it into place with the complete marker. Returns the SDK root, or
      # nil after warning why; whatever install_root held before is kept then.
      def install_managed_flutter_sdk(release, install_root, pinned: false)
        archive = release.fetch("archive")
        url = "#{RELEASES_BASE}/#{archive}"
        label = File.basename(archive)
        announce_managed_flutter_sdk_download(release, url, install_root, pinned: pinned)
        FileUtils.mkdir_p(File.dirname(install_root))
        staging = nil
        Dir.mktmpdir("ruflet-flutter-sdk-") do |tmpdir|
          archive_path = File.join(tmpdir, label)
          download_file(url, archive_path)
          return nil unless VerifiedInstall.verified?(archive_path, release["sha256"], label: label)

          staging = VerifiedInstall.stage(self, archive_path, install_root)
          unless staging
            warn "Failed to extract #{label}"
            return nil
          end
        end

        # Some archives may unpack into a different folder name.
        sdk_dir = staged_flutter_sdk_dir(staging)
        unless sdk_dir
          warn "#{label} does not contain a Flutter SDK; not installing it"
          return nil
        end
        # Another process may have finished the same install meanwhile; never
        # pull an SDK out from under a build that is using it.
        return File.join(install_root, sdk_dir) if completed_managed_flutter_sdk?(install_root, sdk_dir)

        File.write(
          File.join(staging, VerifiedInstall::COMPLETE_MARKER),
          JSON.pretty_generate("version" => release["version"], "archive" => archive, "sha256" => release["sha256"])
        )
        VerifiedInstall.promote(staging, install_root)
        File.join(install_root, sdk_dir)
      ensure
        VerifiedInstall.discard(staging)
      end

      def staged_flutter_sdk_dir(staging)
        return "flutter" if File.executable?(File.join(staging, "flutter", "bin", flutter_executable_name))

        root = Dir.glob(File.join(staging, "**", "bin", flutter_executable_name))
          .select { |path| File.file?(path) && File.executable?(path) }
          .map { |path| File.expand_path("../..", path) }
          .min_by(&:length)
        return nil unless root

        root == staging ? "." : root.delete_prefix("#{staging}/")
      end

      def completed_managed_flutter_sdk?(install_root, sdk_dir)
        File.file?(File.join(install_root, VerifiedInstall::COMPLETE_MARKER)) &&
          File.executable?(File.join(install_root, sdk_dir, "bin", flutter_executable_name))
      end

      # On stderr, so a command whose stdout is Flutter's (`ruflet devices
      # --machine`) stays parseable. The hint only applies without a pin: a
      # pinned version is never taken from the flutter on PATH.
      def announce_managed_flutter_sdk_download(release, url, install_root, pinned: false)
        size = remote_file_size(url)
        size_note = size ? " (#{VerifiedInstall.human_size(size)})" : ""
        notice = "Downloading Flutter #{release['version']}#{size_note} to #{install_root}."
        unless pinned
          notice += " To use your own SDK, put flutter on PATH, or pin a version with RUFLET_FLUTTER_VERSION or .fvmrc."
        end
        warn notice
      end

      def remote_file_size(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
          req = Net::HTTP::Head.new(uri)
          req["User-Agent"] = "ruflet-cli"
          http.request(req)
        end
        return nil unless response.is_a?(Net::HTTPSuccess)

        size = Integer(response["content-length"].to_s, 10)
        size.positive? ? size : nil
      rescue StandardError
        nil
      end

      # install_root is ~/.ruflet/flutter/<version>/<host>, holding flutter/.
      # An install this CLI completed carries the marker. One made before
      # installs were marked (or extracted in place by an older CLI) has no
      # marker: it is accepted once its `flutter --version` succeeds, which
      # marks it, and is otherwise marked incomplete and left for a fresh
      # download of that version to replace.
      def managed_flutter_sdk_complete?(install_root)
        flutter_bin = File.join(install_root, "flutter", "bin", flutter_executable_name)
        return false unless File.file?(flutter_bin) && File.executable?(flutter_bin)
        return true if File.file?(File.join(install_root, VerifiedInstall::COMPLETE_MARKER))
        return false if File.file?(File.join(install_root, INCOMPLETE_MARKER))

        works = legacy_flutter_sdk_works?(flutter_bin)
        unless works
          warn "Ignoring the Flutter SDK at #{File.dirname(File.dirname(flutter_bin))}: " \
               "`flutter --version` fails there, so it may be a partial install"
        end
        marker = File.join(install_root, works ? VerifiedInstall::COMPLETE_MARKER : INCOMPLETE_MARKER)
        File.write(marker, JSON.pretty_generate("checked" => "flutter --version", "at" => Time.now.utc.to_s))
        works
      rescue SystemCallError
        works || false
      end

      # A partial SDK can try to rebuild its tool or fetch its Dart SDK, so
      # the check gives up after `timeout` seconds. bin/flutter is a script
      # that starts those as children, so it runs in its own process group
      # and the whole group is killed: a surviving child would keep running
      # (and may hold bin/cache/lockfile). Ctrl-C during the check kills the
      # group too, since a separate group does not get the terminal's SIGINT.
      def legacy_flutter_sdk_works?(flutter_bin, timeout: LEGACY_SDK_PROBE_SECONDS)
        group = windows_host? ? {} : { pgroup: true }
        pid = Process.spawn(utf8_locale_env, flutter_bin, "--version", out: File::NULL, err: File::NULL, in: File::NULL, **group)
        reaped = false
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        begin
          loop do
            _, status = Process.wait2(pid, Process::WNOHANG)
            if status
              reaped = true
              return status.success?
            end
            return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

            sleep 0.1
          end
        ensure
          unless reaped
            kill_process_tree(pid)
            begin
              Process.wait(pid)
            rescue SystemCallError
              nil
            end
          end
        end
      rescue SystemCallError
        false
      end

      # pid leads its own process group off Windows; taskkill /T ends the
      # tree there.
      def kill_process_tree(pid)
        if windows_host?
          system("taskkill", "/T", "/F", "/PID", pid.to_s, out: File::NULL, err: File::NULL)
          Process.kill("KILL", pid)
        else
          Process.kill("KILL", -pid)
        end
      rescue SystemCallError
        nil
      end

      # An SDK ensure_flutter_sdk_downloaded installed earlier, found on disk
      # without the release manifest: ~/.ruflet/flutter/<version>/<host>/flutter.
      # An explicit version pin (RUFLET_FLUTTER_VERSION or .fvmrc) only accepts
      # that exact version; otherwise the newest installed SDK wins, preferring
      # stable releases on the stable channel. Only complete installs count
      # (see managed_flutter_sdk_complete?).
      def installed_managed_flutter_sdk_root(client_dir: nil)
        host = flutter_host
        return nil unless host

        base = File.join(Dir.home, ".ruflet", "flutter")
        return nil unless File.directory?(base)

        installed = Dir.children(base).sort.filter_map do |version|
          install_root = File.join(base, version, host)
          flutter_bin = File.join(install_root, "flutter", "bin", flutter_executable_name)
          [version, install_root] if File.file?(flutter_bin) && File.executable?(flutter_bin)
        end
        return nil if installed.empty?

        desired = desired_flutter_spec(client_dir: client_dir)
        pinned = desired[:version].to_s.split("@").first.to_s.strip
        candidates = installed.select { |version, _| version == pinned }
        if candidates.empty?
          return nil if pinned.match?(/\A\d+\.\d+\.\d+/)

          stable_only = (desired[:channel] || DEFAULT_FLUTTER_CHANNEL) == DEFAULT_FLUTTER_CHANNEL
          candidates = installed.sort_by do |version, _|
            parsed = Gem::Version.correct?(version) ? Gem::Version.new(version) : Gem::Version.new("0")
            [stable_only && parsed.prerelease? ? 0 : 1, parsed]
          end.reverse
        end
        found = candidates.find { |_, install_root| managed_flutter_sdk_complete?(install_root) }
        found && File.join(found.last, "flutter")
      rescue SystemCallError
        nil
      end

      def resolve_flutter_release(client_dir: nil)
        host = flutter_host
        return nil unless host

        manifest = flutter_releases_manifest_for(host)
        return nil unless manifest

        desired = desired_flutter_spec(client_dir: client_dir)
        release = pick_release(
          manifest,
          version: desired[:version],
          revision: desired[:revision],
          channel: desired[:channel]
        )
        return nil unless release

        { release: release, host: host }
      end

      def desired_flutter_version(client_dir: nil)
        desired_flutter_spec(client_dir: client_dir)[:version] || DEFAULT_FLUTTER_CHANNEL
      end

      def desired_flutter_spec(client_dir: nil)
        env = ENV["RUFLET_FLUTTER_VERSION"].to_s.strip
        return { version: env, source: :env } unless env.empty?

        fvm = parse_fvmrc(find_fvmrc(client_dir))
        return { version: fvm, source: :fvmrc } if fvm

        metadata = parse_flutter_metadata(find_flutter_metadata(client_dir))
        if metadata
          return {
            channel: metadata[:channel] || DEFAULT_FLUTTER_CHANNEL,
            source: :metadata
          }
        end

        { channel: DEFAULT_FLUTTER_CHANNEL, version: DEFAULT_FLUTTER_CHANNEL, source: :default }
      end

      def fvm_project_dir(client_dir: nil)
        return client_dir if client_dir

        cwd_fvmrc = find_fvmrc(nil)
        return File.dirname(cwd_fvmrc) if cwd_fvmrc

        File.join(Dir.home, ".ruflet", "fvm_project")
      end

      def existing_fvm_flutter_bin(project_dir)
        flutter = flutter_bin_path(project_dir)
        return flutter if File.executable?(flutter)

        nil
      end

      def flutter_bin_path(project_dir)
        File.join(project_dir, ".fvm", "flutter_sdk", "bin", flutter_executable_name)
      end

      def find_fvmrc(client_dir)
        candidates = []
        candidates << File.join(client_dir, ".fvmrc") if client_dir
        candidates << File.join(Dir.pwd, ".fvmrc")
        candidates.find { |p| File.file?(p) }
      end

      def find_flutter_metadata(client_dir)
        candidates = []
        candidates << File.join(client_dir, ".metadata") if client_dir
        repo_client = File.expand_path("../../../../../ruflet_client/.metadata", __dir__)
        template_client = File.expand_path("../../../../../templates/ruflet_flutter_template/.metadata", __dir__)
        candidates << repo_client
        candidates << template_client
        if Ruflet::CLI.respond_to?(:cached_ruflet_client_template_root, true)
          candidates << File.join(Ruflet::CLI.send(:cached_ruflet_client_template_root), ".metadata")
        end
        candidates.find { |path| File.file?(path) }
      end

      def parse_fvmrc(path)
        return nil unless path && File.file?(path)

        raw = File.read(path).strip
        return nil if raw.empty?

        if raw.start_with?("{")
          json = JSON.parse(raw) rescue {}
          val = json["flutter"] || json["flutterSdkVersion"] || json["flutter_version"]
          return val.to_s.strip unless val.to_s.strip.empty?
        end

        raw
      end

      def parse_flutter_metadata(path)
        return nil unless path && File.file?(path)

        parsed = YAML.safe_load(File.read(path), aliases: true) || {}
        version_info = parsed["version"]
        return nil unless version_info.is_a?(Hash)

        revision = version_info["revision"].to_s.strip
        channel = version_info["channel"].to_s.strip
        return nil if revision.empty?

        {
          revision: revision,
          channel: channel.empty? ? DEFAULT_FLUTTER_CHANNEL : channel
        }
      rescue StandardError
        nil
      end

      # Flutter publishes one macOS manifest, releases_macos.json, for both
      # architectures (releases_macos_arm64.json does not exist); each entry
      # names its dart_sdk_arch. Keep only this Mac's architecture.
      def flutter_releases_manifest_for(host)
        return fetch_releases_manifest(host) unless host.start_with?("macos")

        manifest = fetch_releases_manifest("macos")
        return nil unless manifest

        arch = host == "macos_arm64" ? "arm64" : "x64"
        manifest.merge("releases" => manifest.fetch("releases", []).select { |r| flutter_release_arch(r) == arch })
      end

      # Releases from before Apple Silicon builds existed name no arch: x64.
      def flutter_release_arch(release)
        arch = release["dart_sdk_arch"].to_s.strip
        return arch unless arch.empty?

        release["archive"].to_s.include?("_arm64_") ? "arm64" : "x64"
      end

      def fetch_releases_manifest(host)
        url = "#{RELEASES_BASE}/releases_#{host}.json"
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          req = Net::HTTP::Get.new(uri)
          req["User-Agent"] = "ruflet-cli"
          http.request(req)
        end
        return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

        nil
      end

      def pick_release(manifest, version: nil, revision: nil, channel: nil)
        releases = manifest.fetch("releases", [])
        if revision
          pinned = releases.find { |r| r["hash"] == revision }
          return pinned if pinned
          warn "Requested Flutter revision #{revision} not found for host #{flutter_host}; falling back."
        end

        # "stable" is the unpinned default, a channel rather than a version.
        if version && version != DEFAULT_FLUTTER_CHANNEL
          pinned = releases.find { |r| r["channel"] == "stable" && r["version"] == version }
          return pinned if pinned
          warn "Requested Flutter #{version} not found in stable releases; falling back to latest stable."
        end

        current = manifest.fetch("current_release", {})[(channel || "stable")]
        if current
          by_hash = releases.find { |r| r["hash"] == current }
          return by_hash if by_hash
        end

        releases.reverse.find { |r| r["channel"] == (channel || "stable") } ||
          releases.reverse.find { |r| r["channel"] == "stable" }
      end

      def flutter_host
        os = RbConfig::CONFIG["host_os"]
        if os.match?(/darwin/i)
          return machine_arch.include?("arm") ? "macos_arm64" : "macos"
        end
        return "linux" if os.match?(/linux/i)
        return "windows" if os.match?(/mswin|mingw|cygwin/i)

        nil
      end

      def machine_arch
        RbConfig::CONFIG["host_cpu"].to_s.downcase
      end

      def windows_host?
        RbConfig::CONFIG["host_os"].match?(/mswin|mingw|cygwin/i)
      end

      def flutter_executable_name
        windows_host? ? "flutter.bat" : "flutter"
      end

      def dart_executable_name
        windows_host? ? "dart.bat" : "dart"
      end

      def fvm_executable_name
        windows_host? ? "fvm.bat" : "fvm"
      end

      def pub_cache_bin_dir
        File.join(Dir.home, ".pub-cache", "bin")
      end

      def which_command(name)
        exts = windows_host? ? ENV.fetch("PATHEXT", ".EXE;.BAT;.CMD").split(";") : [""]
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
          exts.each do |ext|
            candidate = File.join(dir, "#{name}#{ext}")
            return candidate if File.file?(candidate) && File.executable?(candidate)
          end
        end
        nil
      end

      def download_file(url, destination, limit: 5)
        raise "Too many redirects while downloading #{url}" if limit <= 0

        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          req = Net::HTTP::Get.new(uri)
          req["User-Agent"] = "ruflet-cli"
          http.request(req) do |res|
            case res
            when Net::HTTPSuccess
              File.open(destination, "wb") { |f| res.read_body { |chunk| f.write(chunk) } }
              return destination
            when Net::HTTPRedirection
              return download_file(res["location"], destination, limit: limit - 1)
            else
              raise "Download failed (#{res.code})"
            end
          end
        end
      end

      def extract_archive(archive, destination)
        if archive.end_with?(".zip")
          if windows_host?
            return system("powershell", "-NoProfile", "-Command", expand_archive_command(archive, destination))
          end
          return system("unzip", "-oq", archive, "-d", destination)
        end

        if archive.end_with?(".tar.xz") || archive.end_with?(".tar.gz") || archive.end_with?(".tgz")
          return system("tar", "-xf", archive, "-C", destination)
        end

        false
      end

      # PowerShell single-quoted strings take every character literally except
      # the quote itself, which is doubled; -LiteralPath also keeps [ and ]
      # from being read as wildcards.
      def expand_archive_command(archive, destination)
        quote = ->(path) { "'#{path.to_s.gsub("'", "''")}'" }
        "Expand-Archive -LiteralPath #{quote.call(archive)} -DestinationPath #{quote.call(destination)} -Force"
      end
    end
  end
end
