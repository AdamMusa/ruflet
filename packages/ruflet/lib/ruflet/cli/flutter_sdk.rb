# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "open3"
require "rbconfig"
require "tmpdir"
require "uri"
require "yaml"

module Ruflet
  module CLI
    module FlutterSdk
      RELEASES_BASE = "https://storage.googleapis.com/flutter_infra_release/releases".freeze
      DEFAULT_FLUTTER_CHANNEL = "stable".freeze

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
        # Always use FVM so Flutter/Dart match pinned SDK.
        fvm_tools = flutter_tools_via_fvm(client_dir: client_dir, auto_install: auto_install)
        return fvm_tools if fvm_tools

        nil
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

        flutter = File.join(project_dir, ".fvm", "flutter_sdk", "bin", windows_host? ? "flutter.bat" : "flutter")
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
          dart = sdk_root ? File.join(sdk_root, "bin", windows_host? ? "dart.bat" : "dart") : nil
        end
        return nil unless dart && File.executable?(dart)

        system(dart, "pub", "global", "activate", "fvm", out: File::NULL, err: File::NULL)
        which_command("fvm")
      end

      def fvm_env
        pub_bin = File.join(Dir.home, ".pub-cache", "bin")
        { "PATH" => "#{pub_bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}" }
      end

      def tools_from_flutter_bin(flutter_bin)
        return nil unless File.executable?(flutter_bin)

        bin_dir = File.dirname(flutter_bin)
        dart = File.join(bin_dir, windows_host? ? "dart.bat" : "dart")
        {
          flutter: flutter_bin,
          dart: (File.executable?(dart) ? dart : "dart"),
          env: { "PATH" => "#{bin_dir}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH', '')}" }
        }
      end

      def ensure_flutter_sdk_downloaded(client_dir: nil)
        release_info = resolve_flutter_release(client_dir: client_dir)
        return nil unless release_info

        release = release_info[:release]
        host = release_info[:host]
        archive = release.fetch("archive")
        install_root = File.join(Dir.home, ".ruflet", "flutter", release.fetch("version"), host)
        sdk_root = File.join(install_root, "flutter")
        flutter_bin = File.join(sdk_root, "bin", windows_host? ? "flutter.bat" : "flutter")
        return sdk_root if File.executable?(flutter_bin)

        FileUtils.mkdir_p(install_root)
        Dir.mktmpdir("ruflet-flutter-sdk-") do |tmpdir|
          archive_path = File.join(tmpdir, File.basename(archive))
          download_file("#{RELEASES_BASE}/#{archive}", archive_path)
          extract_archive(archive_path, install_root)
        end

        return sdk_root if File.executable?(flutter_bin)

        # Some archives may unpack into a different folder name.
        guessed = Dir.glob(File.join(install_root, "**", windows_host? ? "flutter.bat" : "flutter"))
          .map { |p| File.expand_path("../..", p) }
          .find { |root| File.executable?(File.join(root, "bin", windows_host? ? "flutter.bat" : "flutter")) }
        return guessed if guessed

        nil
      rescue StandardError => e
        warn "Flutter auto-install failed: #{e.class}: #{e.message}"
        nil
      end

      def resolve_flutter_release(client_dir: nil)
        host = flutter_host
        return nil unless host

        manifest = fetch_releases_manifest(host)
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
        return metadata.merge(source: :metadata) if metadata

        { channel: DEFAULT_FLUTTER_CHANNEL, version: DEFAULT_FLUTTER_CHANNEL, source: :default }
      end

      def fvm_project_dir(client_dir: nil)
        return client_dir if client_dir

        cwd_fvmrc = find_fvmrc(nil)
        return File.dirname(cwd_fvmrc) if cwd_fvmrc

        File.join(Dir.home, ".ruflet", "fvm_project")
      end

      def existing_fvm_flutter_bin(project_dir)
        flutter = File.join(project_dir, ".fvm", "flutter_sdk", "bin", windows_host? ? "flutter.bat" : "flutter")
        return flutter if File.executable?(flutter)

        nil
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

        if version
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
            return system("powershell", "-NoProfile", "-Command", "Expand-Archive -Path '#{archive}' -DestinationPath '#{destination}' -Force")
          end
          return system("unzip", "-oq", archive, "-d", destination)
        end

        if archive.end_with?(".tar.xz") || archive.end_with?(".tar.gz") || archive.end_with?(".tgz")
          return system("tar", "-xf", archive, "-C", destination)
        end

        false
      end
    end
  end
end
