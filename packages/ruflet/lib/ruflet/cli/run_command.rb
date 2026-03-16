# frozen_string_literal: true

require "optparse"
require "rbconfig"
require "socket"
require "timeout"
require "tmpdir"
require "fileutils"
require "json"
require "net/http"
require "uri"
require "thread"
require "io/console"
require "time"

module Ruflet
  module CLI
    module RunCommand
      def command_run(args)
        options = { target: "mobile", requested_port: 8550 }
        parser = OptionParser.new do |o|
          o.on("--web") { options[:target] = "web" }
          o.on("--desktop") { options[:target] = "desktop" }
          o.on("--port PORT", Integer) { |v| options[:requested_port] = v }
        end
        parser.parse!(args)

        script_token = args.shift || "main"
        script_path = resolve_script(script_token)
        unless script_path
          warn "Script not found: #{script_token}"
          warn "Expected: ./#{script_token}.rb, ./#{script_token}, or explicit file path."
          return 1
        end

        selected_port = resolve_backend_port(options[:target], requested_port: options[:requested_port])
        return 1 unless selected_port
        env = {
          "RUFLET_TARGET" => options[:target],
          "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
          "RUFLET_PORT" => selected_port.to_s
        }
        assets_dir = File.join(File.dirname(script_path), "assets")
        env["RUFLET_ASSETS_DIR"] = assets_dir if File.directory?(assets_dir)

        print_run_banner(target: options[:target], requested_port: options[:requested_port], port: selected_port)
        print_mobile_qr_hint(port: selected_port) if options[:target] == "mobile"

        gemfile_path = find_nearest_gemfile(Dir.pwd)
        cmd = build_runtime_command(script_path, gemfile_path: gemfile_path, env: env)
        return 1 unless cmd

        child_pid = Process.spawn(env, *cmd, pgroup: true)
        launched_client_pids = launch_target_client(options[:target], selected_port)
        forward_signal = lambda do |signal|
          begin
            Process.kill(signal, -child_pid)
          rescue Errno::ESRCH
            nil
          end
        end

        previous_int = Signal.trap("INT") { forward_signal.call("INT") }
        previous_term = Signal.trap("TERM") { forward_signal.call("TERM") }

        _pid, status = Process.wait2(child_pid)
        status.success? ? 0 : (status.exitstatus || 1)
      ensure
        Signal.trap("INT", previous_int) if defined?(previous_int) && previous_int
        Signal.trap("TERM", previous_term) if defined?(previous_term) && previous_term

        if defined?(child_pid) && child_pid
          begin
            Process.kill("TERM", -child_pid)
          rescue Errno::ESRCH
            nil
          end
        end

        Array(defined?(launched_client_pids) ? launched_client_pids : nil).compact.each do |pid|
          begin
            Process.kill("TERM", -pid)
          rescue Errno::ESRCH
            begin
              Process.kill("TERM", pid)
            rescue Errno::ESRCH
              nil
            end
          end
        end

      end

      private

      def build_runtime_command(script_path, gemfile_path:, env:)
        if gemfile_path
          env["BUNDLE_GEMFILE"] = gemfile_path
          bundle_ready = system(env, RbConfig.ruby, "-S", "bundle", "check", out: File::NULL, err: File::NULL)
          return nil unless bundle_ready || system(env, RbConfig.ruby, "-S", "bundle", "install")

          return [RbConfig.ruby, "-rbundler/setup", script_path]
        end

        [RbConfig.ruby, script_path]
      end

      def resolve_script(token)
        path = File.expand_path(token, Dir.pwd)
        return path if File.file?(path)

        candidate = File.expand_path("#{token}.rb", Dir.pwd)
        return candidate if File.file?(candidate)

        nil
      end

      def find_nearest_gemfile(start_dir)
        current = File.expand_path(start_dir)
        loop do
          candidate = File.join(current, "Gemfile")
          return candidate if File.file?(candidate)

          parent = File.expand_path("..", current)
          return nil if parent == current

          current = parent
        end
      end

      def print_run_banner(target:, requested_port:, port:)
        if port != requested_port.to_i
          puts "Requested port #{requested_port} is busy; bound to #{port}"
        end
        if target == "desktop"
          puts "Ruflet desktop URL: http://localhost:#{port}"
        elsif target == "mobile"
          puts "Ruflet target: #{target}"
        else
          puts "Ruflet target: #{target}"
          puts "Ruflet URL: http://localhost:#{port}"
        end
      end

      def launch_target_client(target, port)
        wait_for_server_boot(port)

        case target
        when "web"
          launch_web_client(port)
        when "desktop"
          launch_desktop_client("http://localhost:#{port}")
        else
          []
        end
      end

      def launch_web_client(port)
        web_dir = detect_web_client_dir
        unless web_dir
          warn "Web client build not found and prebuilt download failed."
          return []
        end

        web_port = find_available_port(port + 1)
        web_pid = Process.spawn("python3", "-m", "http.server", web_port.to_s, "--bind", "127.0.0.1", chdir: web_dir, out: File::NULL, err: File::NULL)
        Process.detach(web_pid)
        wait_for_server_boot(web_port)
        backend_url = "http://localhost:#{port}"
        web_url = "http://localhost:#{web_port}/?#{URI.encode_www_form(url: backend_url)}"
        browser_pid = open_in_browser_app_mode(web_url)
        open_in_browser(web_url) if browser_pid.nil?
        puts "Ruflet web client: #{web_url}"
        puts "Ruflet backend ws: ws://localhost:#{port}/ws"
        [web_pid, browser_pid].compact
      rescue Errno::ENOENT
        warn "python3 is required to host web client locally."
        warn "Install Python 3 and rerun."
        []
      rescue StandardError => e
        warn "Failed to launch web client: #{e.class}: #{e.message}"
        []
      end

      def wait_for_server_boot(port, timeout_seconds: 10)
        Timeout.timeout(timeout_seconds) do
          loop do
            begin
              sock = TCPSocket.new("127.0.0.1", port)
              sock.write("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
              sock.close
              break
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              sleep 0.15
            end
          end
        end
      rescue Timeout::Error
        warn "Server did not become reachable at http://localhost:#{port} yet."
      end

      def open_in_browser(url)
        cmd =
          case RbConfig::CONFIG["host_os"]
          when /darwin/i
            ["open", url]
          when /mswin|mingw|cygwin/i
            ["cmd", "/c", "start", "", url]
          else
            ["xdg-open", url]
          end
        if system(*cmd, out: File::NULL, err: File::NULL)
          puts "Opened browser at #{url}"
        else
          warn "Could not auto-open browser. Open manually: #{url}"
        end
      end

      def open_in_browser_app_mode(url)
        host_os = RbConfig::CONFIG["host_os"]
        if host_os.match?(/darwin/i)
          chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
          chromium = "/Applications/Chromium.app/Contents/MacOS/Chromium"
          browser = [chrome, chromium].find { |p| File.file?(p) && File.executable?(p) }
          return nil unless browser

          profile_dir = Dir.mktmpdir("ruflet-webapp-")
          pid = Process.spawn(
            browser,
            "--new-window",
            "--no-first-run",
            "--no-default-browser-check",
            "--user-data-dir=#{profile_dir}",
            "--app=#{url}",
            pgroup: true,
            out: File::NULL,
            err: File::NULL
          )
          Process.detach(pid)
          return pid
        end

        if host_os.match?(/linux/i)
          browser = %w[google-chrome chromium chromium-browser].find { |cmd| system("which", cmd, out: File::NULL, err: File::NULL) }
          return nil unless browser

          profile_dir = Dir.mktmpdir("ruflet-webapp-")
          pid = Process.spawn(
            browser,
            "--new-window",
            "--no-first-run",
            "--no-default-browser-check",
            "--user-data-dir=#{profile_dir}",
            "--app=#{url}",
            pgroup: true,
            out: File::NULL,
            err: File::NULL
          )
          Process.detach(pid)
          return pid
        end

        nil
      rescue StandardError
        nil
      end

      def launch_desktop_client(url)
        cmd = detect_desktop_client_command(url)
        unless cmd
          warn "Desktop client executable not found."
          warn "Set RUFLET_CLIENT_DIR to your client path."
          warn "Example: export RUFLET_CLIENT_DIR=/path/to/ruflet_client"
          return
        end

        pid = Process.spawn(*cmd, out: File::NULL, err: File::NULL)
        Process.detach(pid)
        if !pid
          warn "Failed to launch desktop client: #{cmd.first}"
          warn "Start it manually with URL: #{url}"
        end
        [pid]
      rescue StandardError => e
        warn "Failed to launch desktop client: #{e.class}: #{e.message}"
        warn "Start it manually with URL: #{url}"
        []
      end

      def detect_desktop_client_command(url)
        root = ENV["RUFLET_CLIENT_DIR"]
        root = File.expand_path("ruflet_client", Dir.pwd) if root.to_s.strip.empty?
        root = nil unless Dir.exist?(root)
        root ||= ensure_prebuilt_client(desktop: true)
        return nil unless root && Dir.exist?(root)

        host_os = RbConfig::CONFIG["host_os"]
        if host_os.match?(/darwin/i)
          release_bin = File.join(root, "build", "macos", "Build", "Products", "Release", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
          debug_bin = File.join(root, "build", "macos", "Build", "Products", "Debug", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
          prebuilt_bin = File.join(root, "desktop", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
          executable = [release_bin, debug_bin].find { |p| File.file?(p) && File.executable?(p) }
          executable ||= prebuilt_bin if File.file?(prebuilt_bin) && File.executable?(prebuilt_bin)
          return [executable, url] if executable
        elsif host_os.match?(/mswin|mingw|cygwin/i)
          exe = File.join(root, "build", "windows", "x64", "runner", "Release", "ruflet_client.exe")
          prebuilt = File.join(root, "desktop", "ruflet_client.exe")
          exe = prebuilt if !File.file?(exe) && File.file?(prebuilt)
          return [exe, url] if File.file?(exe)
        else
          direct = File.join(root, "build", "linux", "x64", "release", "bundle", "ruflet_client")
          prebuilt_direct = File.join(root, "desktop", "ruflet_client")
          direct = prebuilt_direct if !File.file?(direct) && File.file?(prebuilt_direct)
          return [direct, url] if File.file?(direct)
          bundle_dir = File.join(root, "build", "linux", "x64", "release", "bundle")
          if Dir.exist?(bundle_dir)
            candidate = Dir.children(bundle_dir).map { |f| File.join(bundle_dir, f) }
              .find { |path| File.file?(path) && File.executable?(path) }
            return [candidate, url] if candidate
          end
        end

        nil
      end

      def detect_web_client_dir
        root = ENV["RUFLET_CLIENT_DIR"]
        root = File.expand_path("ruflet_client", Dir.pwd) if root.to_s.strip.empty?
        root = nil unless Dir.exist?(root)
        root ||= ensure_prebuilt_client(web: true)
        return nil unless root && Dir.exist?(root)

        built = File.join(root, "build", "web")
        return built if Dir.exist?(built) && File.file?(File.join(built, "index.html"))
        prebuilt = File.join(root, "web")
        return prebuilt if Dir.exist?(prebuilt) && File.file?(File.join(prebuilt, "index.html"))

        nil
      end

      def ensure_prebuilt_client(web: false, desktop: false, platform: nil, force: false)
        platform ||= host_platform_name
        return nil if platform.nil?

        cache_root = client_cache_root_for(platform)
        FileUtils.mkdir_p(cache_root)

        wanted_assets = []
        wanted_assets << { kind: :web, name: "ruflet_client-web.tar.gz" } if web
        if desktop
          desktop_asset = desktop_asset_name_for(platform)
          return nil if desktop_asset.nil?
          wanted_assets << { kind: :desktop, name: desktop_asset, platform: platform }
        end
        if !force && (wanted_assets.empty? || prebuilt_assets_present?(cache_root, web: web, desktop: desktop, platform: platform))
          ensure_client_manifest(cache_root, platform: platform)
          return cache_root
        end

        release = fetch_release_for_version
        return nil unless release

        assets = release.fetch("assets", [])
        asset_names = assets.map { |a| a["name"].to_s }
        installed_assets = []
        Dir.mktmpdir("ruflet-prebuilt-") do |tmpdir|
          wanted_assets.each do |wanted|
            asset_name = wanted.fetch(:name)
            asset = assets.find { |a| a["name"] == asset_name }
            asset ||= fallback_release_asset(assets, wanted)
            unless asset
              warn "Missing release asset: #{asset_name}"
              warn "Available assets: #{asset_names.join(', ')}" unless asset_names.empty?
              return nil
            end
            resolved_name = asset.fetch("name")
            puts "Downloading prebuilt client asset: #{resolved_name}"
            archive_path = File.join(tmpdir, resolved_name)
            download_file(asset.fetch("browser_download_url"), archive_path)
            subdir = wanted[:kind] == :web ? "web" : "desktop"
            target = File.join(cache_root, subdir)
            FileUtils.rm_rf(target) if force && Dir.exist?(target)
            FileUtils.mkdir_p(target)
            unless extract_archive(archive_path, target)
              warn "Failed to extract asset: #{resolved_name}"
              return nil
            end
            installed_assets << {
              "kind" => wanted[:kind].to_s,
              "platform" => wanted[:platform] || platform,
              "asset_name" => resolved_name,
              "download_url" => asset.fetch("browser_download_url")
            }
          end
        end

        if prebuilt_assets_present?(cache_root, web: web, desktop: desktop, platform: platform)
          write_client_manifest(cache_root, platform: platform, release: release, assets: installed_assets)
          return cache_root
        end

        nil
      rescue StandardError => e
        warn "Prebuilt client bootstrap failed: #{e.class}: #{e.message}"
        nil
      end

      def prebuilt_assets_present?(root, web:, desktop:, platform: nil)
        ok_web = !web || File.file?(File.join(root, "web", "index.html"))
        ok_desktop = !desktop || prebuilt_desktop_present?(root, platform: platform)
        ok_web && ok_desktop
      end

      def prebuilt_desktop_present?(root, platform: nil)
        platform ||= host_platform_name
        return false if platform.nil?

        case platform
        when "macos"
          File.file?(File.join(root, "desktop", "ruflet_client.app", "Contents", "MacOS", "ruflet_client"))
        when "linux"
          File.file?(File.join(root, "desktop", "ruflet_client"))
        when "windows"
          File.file?(File.join(root, "desktop", "ruflet_client.exe"))
        else
          false
        end
      end

      def host_platform_name
        host_os = RbConfig::CONFIG["host_os"]
        return "macos" if host_os.match?(/darwin/i)
        return "linux" if host_os.match?(/linux/i)
        return "windows" if host_os.match?(/mswin|mingw|cygwin/i)

        nil
      end

      def desktop_asset_name_for(platform)
        case platform
        when "macos" then "ruflet_client-macos-universal.zip"
        when "linux" then "ruflet_client-linux-x64.tar.gz"
        when "windows" then "ruflet_client-windows-x64.zip"
        end
      end

      def client_cache_root_for(platform)
        File.join(Dir.home, ".ruflet", "client", ruflet_version, platform.to_s)
      end

      def fetch_release_for_version
        release_by_tag("v#{ruflet_version}") ||
          release_by_tag(ruflet_version) ||
          release_by_tag("prebuild") ||
          release_by_tag("prebuild-main") ||
          release_latest
      end

      def ruflet_version
        return Ruflet::VERSION if Ruflet.const_defined?(:VERSION)

        require_relative "../version"
        Ruflet::VERSION
      end

      def release_latest
        github_get_json("https://api.github.com/repos/AdamMusa/Ruflet/releases/latest")
      end

      def release_by_tag(tag)
        github_get_json("https://api.github.com/repos/AdamMusa/Ruflet/releases/tags/#{tag}")
      rescue StandardError
        nil
      end

      def fallback_release_asset(assets, wanted)
        kind = wanted[:kind]
        platform = wanted[:platform]
        candidates = assets.select { |asset| release_asset_matches?(asset.fetch("name", ""), kind, platform) }
        candidates.first
      end

      def release_asset_matches?(name, kind, platform)
        n = name.to_s.downcase
        return false unless n.include?("ruflet_client")

        if kind == :web
          return n.include?("web") && (n.end_with?(".tar.gz") || n.end_with?(".zip"))
        end

        case platform
        when "macos"
          n.include?("macos") && n.end_with?(".zip")
        when "linux"
          n.include?("linux") && (n.end_with?(".tar.gz") || n.end_with?(".tgz"))
        when "windows"
          n.include?("windows") && n.end_with?(".zip")
        else
          false
        end
      end

      def github_get_json(url)
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          req = Net::HTTP::Get.new(uri)
          req["Accept"] = "application/vnd.github+json"
          req["User-Agent"] = "ruflet-cli"
          http.request(req)
        end
        return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

        raise "GitHub API failed (#{response.code})"
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
        if archive.end_with?(".tar.gz")
          return system("tar", "-xzf", archive, "-C", destination, out: File::NULL, err: File::NULL)
        end
        if archive.end_with?(".zip")
          host_os = RbConfig::CONFIG["host_os"]
          if host_os.match?(/darwin/i)
            return system("ditto", "-x", "-k", archive, destination, out: File::NULL, err: File::NULL)
          end
          return system("unzip", "-oq", archive, "-d", destination, out: File::NULL, err: File::NULL)
        end

        false
      end

      def client_manifest_path(root)
        File.join(root, "manifest.json")
      end

      def read_client_manifest(root)
        path = client_manifest_path(root)
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      rescue StandardError
        nil
      end

      def ensure_client_manifest(root, platform:)
        return if read_client_manifest(root)

        assets = []
        assets << { "kind" => "web", "platform" => platform, "asset_name" => nil } if File.file?(File.join(root, "web", "index.html"))
        if prebuilt_desktop_present?(root, platform: platform)
          assets << { "kind" => "desktop", "platform" => platform, "asset_name" => nil }
        end
        return if assets.empty?

        write_client_manifest(root, platform: platform, release: nil, assets: assets)
      end

      def write_client_manifest(root, platform:, release:, assets:)
        FileUtils.mkdir_p(root)
        payload = {
          "schema" => 1,
          "ruflet_version" => ruflet_version,
          "platform" => platform,
          "release_tag" => release && release["tag_name"],
          "released_at" => release && release["published_at"],
          "installed_at" => Time.now.utc.iso8601,
          "targets" => assets
        }
        File.write(client_manifest_path(root), JSON.pretty_generate(payload))
      end

      def print_mobile_qr_hint(port: 8550)
        host = best_lan_host
        payload = "http://#{host}:#{port}"

        puts
        puts "Ruflet mobile connect URL:"
        puts "  #{payload}"
        puts "Scan this QR from ruflet_client (Connect -> Scan QR):"
        print_ascii_qr(payload)
        puts
      rescue StandardError => e
        warn "QR setup failed: #{e.class}: #{e.message}"
      end

      def find_available_port(start_port, max_attempts: 100)
        port = start_port.to_i

        max_attempts.times do
          begin
            begin
              probe = TCPServer.new("0.0.0.0", port)
            rescue Errno::EACCES, Errno::EPERM
              probe = TCPServer.new("127.0.0.1", port)
            end
            probe.close
            return port
          rescue Errno::EADDRINUSE, Errno::EACCES, Errno::EPERM
            port += 1
          end
        end

        start_port
      end

      def resolve_backend_port(_target, requested_port: 8550)
        base = requested_port.to_i
        base = 8550 if base <= 0
        find_available_port(base)
      end

      def port_available?(port)
        probe = nil
        begin
          begin
            probe = TCPServer.new("0.0.0.0", port)
          rescue Errno::EACCES, Errno::EPERM
            probe = TCPServer.new("127.0.0.1", port)
          end
          true
        rescue Errno::EADDRINUSE
          false
        ensure
          probe&.close
        end
      end

      def best_lan_host
        ips = Socket.ip_address_list
        addr = ips.find { |ip| ip.ipv4_private? && !ip.ipv4_loopback? }
        return addr.ip_address if addr

        "127.0.0.1"
      end

      def print_ascii_qr(payload)
        begin
          require "rqrcode"
        rescue LoadError
          puts "(Install 'rqrcode' gem in CLI package for terminal QR rendering.)"
          return
        end

        q = RQRCode::QRCode.new(payload)
        border = 1
        core = q.modules
        size = core.length + (2 * border)

        matrix = Array.new(size) do |y|
          Array.new(size) do |x|
            cy = y - border
            cx = x - border
            cy >= 0 && cx >= 0 && cy < core.length && cx < core.length && core[cy][cx]
          end
        end

        y = 0
        while y < size
          line = +""
          (0...size).each do |x|
            top = matrix[y][x]
            bottom = (y + 1 < size) ? matrix[y + 1][x] : false
            line << if top && bottom
              "\u2588"
            elsif top
              "\u2580"
            elsif bottom
              "\u2584"
            else
              " "
            end
          end
          puts line
          y += 2
        end
      end
    end
  end
end
