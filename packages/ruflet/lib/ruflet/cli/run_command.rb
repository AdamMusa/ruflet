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
require "open3"
require "time"

module Ruflet
  module CLI
    module RunCommand
      # Release assets were published as ruflet_client-* before the preview
      # client became Ruflet Explorer. Ask for the current names, but keep
      # recognising the old ones so an existing release still resolves.
      ASSET_PREFIX = "ruflet_explorer"
      LEGACY_ASSET_PREFIX = "ruflet_client"
      CLIENT_CHANNEL_MANIFEST = "#{ASSET_PREFIX}-manifest.json"
      LEGACY_CLIENT_CHANNEL_MANIFEST = "#{LEGACY_ASSET_PREFIX}-manifest.json"
      EXPERIMENTAL_IOS_SIMULATOR_ASSET = "#{ASSET_PREFIX}-ios-experimental-simulator.zip"
      EXPERIMENTAL_MACOS_ASSET = "#{ASSET_PREFIX}-macos-experimental-universal.zip"
      DEFAULT_CLIENT_UPDATE_INTERVAL = 6 * 60 * 60

      def command_run(args)
        options = parse_run_options(args)

        script_token = args.shift || "main"
        script_path = resolve_script(script_token)
        unless script_path
          warn "Script not found: #{script_token}"
          warn "Expected: ./#{script_token}.rb, ./#{script_token}, or explicit file path."
          return 1
        end

        experimental_client = prepare_experimental_run_client(options)
        return 1 if options[:experimental] && !experimental_client

        selected_port = resolve_backend_port(options[:target], requested_port: options[:requested_port])
        return 1 unless selected_port
        env = {
          "RUFLET_TARGET" => options[:target],
          "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
          "RUFLET_PORT" => selected_port.to_s
        }
        apply_local_ruflet_dev_overrides(env)
        assets_dir = File.join(File.dirname(script_path), "assets")
        env["RUFLET_ASSETS_DIR"] = assets_dir if File.directory?(assets_dir)

        # The backend serves the web client itself so both share one origin.
        if options[:target] == "web"
          web_client_dir = detect_web_client_dir
          if web_client_dir
            env["RUFLET_WEB_CLIENT_DIR"] = web_client_dir
          else
            warn "Web client build not found and prebuilt download failed."
            warn "Build one with `ruflet build web`, or set RUFLET_CLIENT_DIR."
            return 1
          end
        end

        print_run_banner(target: options[:target], requested_port: options[:requested_port], port: selected_port)
        print_mobile_qr_hint(port: selected_port) if options[:target] == "mobile"
        print_hot_reload_banner if options[:reload]

        gemfile_path = find_nearest_gemfile(Dir.pwd)
        cmd = build_runtime_command(script_path, gemfile_path: gemfile_path, env: env, reload: options[:reload])
        return 1 unless cmd

        run_state = { child_pid: Process.spawn(env, *cmd, pgroup: true), restart: false }
        reload_input_thread = options[:reload] ? start_reload_input_thread(run_state) : nil
        launched_client_pids = launch_target_client(
          options[:target], selected_port,
          experimental_client: experimental_client
        )
        forward_signal = lambda do |signal|
          begin
            Process.kill(signal, -run_state[:child_pid])
          rescue Errno::ESRCH
            nil
          end
        end

        previous_int = Signal.trap("INT") { forward_signal.call("INT") }
        previous_term = Signal.trap("TERM") { forward_signal.call("TERM") }

        loop do
          _pid, status = Process.wait2(run_state[:child_pid])
          return status.success? ? 0 : (status.exitstatus || 1) unless run_state[:restart]

          # Full restart requested ("R"): respawn the backend; connected
          # clients reconnect and re-register on their own (Flet-style).
          run_state[:restart] = false
          puts "Restarting app..."
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          run_state[:child_pid] = Process.spawn(env, *cmd, pgroup: true)
          wait_for_server_boot(selected_port)
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          puts "Restarted in #{elapsed_ms}ms"
        end
      ensure
        reload_input_thread&.kill if defined?(reload_input_thread)
        Signal.trap("INT", previous_int) if defined?(previous_int) && previous_int
        Signal.trap("TERM", previous_term) if defined?(previous_term) && previous_term

        if defined?(run_state) && run_state && run_state[:child_pid]
          begin
            Process.kill("TERM", -run_state[:child_pid])
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

      def parse_run_options(args)
        options = { target: "mobile", requested_port: 8550, reload: true, experimental: false }
        parser = OptionParser.new do |o|
          o.on("--web") { options[:target] = "web" }
          o.on("--desktop") { options[:target] = "desktop" }
          o.on("--port PORT", Integer) { |v| options[:requested_port] = v }
          o.on("--no-reload") { options[:reload] = false }
          o.on("--experimental", "--exp") { options[:experimental] = true }
        end
        parser.parse!(args)
        options
      end

      def prepare_experimental_run_client(options)
        return nil unless options[:experimental]

        if options[:target] == "web"
          warn "run config error: --experimental/--exp is supported only for iOS and macOS"
          return nil
        end
        unless host_platform_name == "macos"
          warn "run config error: the experimental Apple client requires macOS"
          return nil
        end

        if options[:target] == "desktop"
          root = ensure_prebuilt_client(desktop_experimental: true, platform: "macos")
          unless root
            warn "Experimental macOS client is unavailable."
            warn "The release must contain #{EXPERIMENTAL_MACOS_ASSET}."
            return nil
          end

          return { kind: :desktop, root: root }
        end

        root = ensure_prebuilt_client(ios_experimental: true, platform: "macos")
        unless root
          warn "Experimental iOS Simulator client is unavailable."
          warn "The release must contain #{EXPERIMENTAL_IOS_SIMULATOR_ASSET}."
          return nil
        end

        app_bundle = experimental_ios_app_bundle(root)
        simulator = booted_ios_simulator
        unless simulator
          warn "No booted iOS Simulator was found."
          warn "Start the simulator you want to use, then run the command again."
          return nil
        end

        bundle_identifier = ios_bundle_identifier(app_bundle)
        if bundle_identifier.to_s.empty?
          warn "Experimental client has no CFBundleIdentifier: #{app_bundle}"
          return nil
        end

        {
          kind: :ios_simulator,
          app_bundle: app_bundle,
          bundle_identifier: bundle_identifier,
          simulator_udid: simulator.fetch("udid"),
          simulator_name: simulator.fetch("name", simulator.fetch("udid"))
        }
      end

      def build_runtime_command(script_path, gemfile_path:, env:, reload: false)
        entry_script = script_path
        if reload
          env["RUFLET_APP_SCRIPT"] = script_path
          env["RUFLET_WATCH_ROOT"] = File.dirname(script_path)
          env["RUFLET_BOOTSNAP_DIR"] = bootsnap_cache_dir(script_path)
          entry_script = hot_reload_harness_path
        end

        if gemfile_path
          env["BUNDLE_GEMFILE"] = gemfile_path
          bundle_ready = system(env, RbConfig.ruby, "-S", "bundle", "check", out: File::NULL, err: File::NULL)
          return nil unless bundle_ready || system(env, RbConfig.ruby, "-S", "bundle", "install")

          return [RbConfig.ruby, "-rbundler/setup", entry_script]
        end

        [RbConfig.ruby, entry_script]
      end

      def hot_reload_harness_path
        File.expand_path("../hot_reload/harness.rb", __dir__)
      end

      # Persistent, per-app bootsnap cache so it stays warm across restarts.
      # Kept under ~/.ruflet (not the project, so nothing to gitignore) and
      # keyed by app path + Ruby version so bytecode never crosses apps or
      # incompatible VMs.
      def bootsnap_cache_dir(script_path)
        app_key = File.dirname(File.expand_path(script_path)).gsub(/[^a-zA-Z0-9]+/, "-").delete_prefix("-")
        File.join(Dir.home, ".ruflet", "bootsnap", RUBY_VERSION, app_key)
      end

      def manual_reload_supported?
        $stdin.tty? && Signal.list.key?("USR1")
      end

      def print_hot_reload_banner
        hint = manual_reload_supported? ? "; press \"r\" to reload, \"R\" to restart" : ""
        puts "Hot reload: watching *.rb#{hint} (disable with --no-reload)"
      end

      def start_reload_input_thread(run_state)
        return nil unless manual_reload_supported?

        Thread.new do
          loop do
            key = read_reload_key
            break if key.nil?
            break unless handle_reload_command(key, run_state)
          end
        rescue StandardError
          nil
        end
      end

      # Single keypress, no Enter required. getch puts the terminal in raw
      # mode only for the duration of the read; intr keeps Ctrl-C working.
      def read_reload_key
        $stdin.getch(intr: true)
      rescue ArgumentError
        # Older Rubies without the intr keyword.
        $stdin.getch
      rescue StandardError
        nil
      end

      # Returns false when the child process is gone and the thread should end.
      def handle_reload_command(command, run_state)
        case command
        when "r"
          Process.kill("USR1", run_state[:child_pid])
        when "R"
          run_state[:restart] = true
          Process.kill("TERM", -run_state[:child_pid])
          escalate_child_shutdown(run_state[:child_pid])
        end
        true
      rescue Errno::ESRCH
        run_state[:restart] = false
        false
      end

      # An app can block TERM (bad traps, stuck threads); force the restart
      # through with KILL if the child is still running after the grace period.
      def escalate_child_shutdown(child_pid, grace_seconds: 3)
        Thread.new do
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace_seconds
          loop do
            sleep 0.1
            begin
              Process.kill(0, child_pid)
            rescue Errno::ESRCH
              break
            end
            next unless Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

            begin
              Process.kill("KILL", -child_pid)
            rescue Errno::ESRCH
              nil
            end
            break
          end
        end
      end

      def apply_local_ruflet_dev_overrides(env)
        lib_paths = local_ruflet_dev_lib_paths
        return if lib_paths.empty?

        existing = env["RUBYLIB"].to_s
        segments = lib_paths + existing.split(File::PATH_SEPARATOR).reject(&:empty?)
        env["RUBYLIB"] = segments.uniq.join(File::PATH_SEPARATOR)
        puts "Ruflet dev source: #{lib_paths.join(", ")}"
      end

      def local_ruflet_dev_lib_paths
        repo_root = File.expand_path("../../../../../", __dir__)
        package_roots = %w[ruflet_core ruflet_server].map { |name| File.join(repo_root, "packages", name, "lib") }
        return [] unless package_roots.all? { |path| Dir.exist?(path) }

        package_roots
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

      def launch_target_client(target, port, experimental_client: nil)
        wait_for_server_boot(port)

        if experimental_client
          if experimental_client[:kind] == :desktop
            return launch_desktop_client(
              "http://localhost:#{port}",
              root: experimental_client.fetch(:root), experimental: true)
          end

          return launch_experimental_mobile_client(
            "http://#{best_lan_host}:#{port}", client: experimental_client)
        end

        case target
        when "web"
          launch_web_client(port)
        when "desktop"
          launch_desktop_client("http://localhost:#{port}")
        else
          []
        end
      end

      def launch_experimental_mobile_client(url, client:)
        udid = client.fetch(:simulator_udid)
        app_bundle = client.fetch(:app_bundle)
        bundle_identifier = client.fetch(:bundle_identifier)

        unless system("xcrun", "simctl", "install", udid, app_bundle)
          warn "Failed to install the experimental client on #{client[:simulator_name] || udid}."
          return []
        end

        launched = system(
          { "SIMCTL_CHILD_RUFLET_URL" => url },
          "xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle_identifier
        )
        unless launched
          warn "Failed to launch the experimental client on #{client[:simulator_name] || udid}."
          return []
        end

        puts "Ruflet experimental client: #{client[:simulator_name] || udid}"
        puts "Ruflet experimental backend: #{url}"
        []
      rescue StandardError => e
        warn "Failed to launch experimental client: #{e.class}: #{e.message}"
        []
      end

      # The backend serves the web client on its own port, so the client reads
      # the origin it was loaded from and opens its websocket there. No URL is
      # passed in the query string: nothing in the client parses one.
      def launch_web_client(port)
        backend_url = "http://localhost:#{port}"
        web_url = "#{backend_url}/"
        browser_pid = open_in_browser_app_mode(web_url)
        open_in_browser(web_url) if browser_pid.nil?
        puts "Ruflet web client: #{web_url}"
        puts "Ruflet backend ws: ws://localhost:#{port}/ws"
        [browser_pid].compact
      rescue StandardError => e
        warn "Failed to launch web client: #{e.class}: #{e.message}"
        []
      end

      def wait_for_server_boot(port, timeout_seconds: 10, poll_interval: 0.01)
        Timeout.timeout(timeout_seconds) do
          loop do
            begin
              sock = TCPSocket.new("127.0.0.1", port)
              sock.write("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
              sock.close
              break
            rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
              sleep poll_interval
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

      def launch_desktop_client(url, root: nil, experimental: false)
        cmd = detect_desktop_client_command(url, root: root, experimental: experimental)
        unless cmd
          warn "Desktop client executable not found."
          warn "Set RUFLET_CLIENT_DIR to your client path."
          warn "Example: export RUFLET_CLIENT_DIR=/path/to/ruflet_client"
          return
        end

        # The Flutter client took the URL as argv; a Ruflet app used as the
        # client reads RUFLET_URL, so it connects instead of showing its own
        # launcher. Pass both so either client auto-connects.
        pid = Process.spawn({ "RUFLET_URL" => url }, *cmd, out: File::NULL, err: File::NULL)
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

      # A Ruflet app used as the preview client builds its native project into
      # build/client, so its Flutter output is one level deeper than a bare
      # Flutter client's. Search both, and never assume the app is named
      # ruflet_client: the bundle takes the app's own display name.
      def client_build_roots(root)
        [File.join(root, "build", "client"), root].select { |dir| Dir.exist?(dir) }
      end

      def executable_file?(path)
        File.file?(path) && File.executable?(path)
      end

      # A Flutter project's own web/ folder holds a source index.html, so
      # index.html alone would match an unbuilt project. Require a compiled
      # entrypoint as well.
      WEB_BUILD_MARKERS = %w[flutter_bootstrap.js main.dart.js flutter.js].freeze

      def built_web_client_dir?(dir)
        return false unless Dir.exist?(dir) && File.file?(File.join(dir, "index.html"))

        WEB_BUILD_MARKERS.any? { |marker| File.file?(File.join(dir, marker)) }
      end

      def macos_app_executable(app_bundle)
        macos_dir = File.join(app_bundle, "Contents", "MacOS")
        return nil unless Dir.exist?(macos_dir)

        Dir.children(macos_dir)
          .map { |entry| File.join(macos_dir, entry) }
          .find { |path| executable_file?(path) }
      end

      def detect_desktop_client_command(url, root: nil, experimental: false)
        unless root
          root = ENV["RUFLET_CLIENT_DIR"]
          root = File.expand_path("ruflet_client", Dir.pwd) if root.to_s.strip.empty?
          root = nil unless Dir.exist?(root)
          root ||= ensure_prebuilt_client(desktop: true)
        end
        return nil unless root && Dir.exist?(root)

        host_os = RbConfig::CONFIG["host_os"]
        client_build_roots(root).each do |base|
          if host_os.match?(/darwin/i)
            search = %w[Release Debug].map { |config| File.join(base, "build", "macos", "Build", "Products", config) }
            search << File.join(base, experimental ? "desktop-experimental" : "desktop")
            search.each do |dir|
              next unless Dir.exist?(dir)

              Dir.glob(File.join(dir, "*.app")).sort.each do |app_bundle|
                executable = macos_app_executable(app_bundle)
                return [executable, url] if executable
              end
            end
          elsif host_os.match?(/mswin|mingw|cygwin/i)
            search = [
              File.join(base, "build", "windows", "x64", "runner", "Release"),
              File.join(base, "desktop")
            ]
            search.each do |dir|
              next unless Dir.exist?(dir)

              exe = Dir.glob(File.join(dir, "*.exe")).sort.find { |path| File.file?(path) }
              return [exe, url] if exe
            end
          else
            search = [
              File.join(base, "build", "linux", "x64", "release", "bundle"),
              File.join(base, "desktop")
            ]
            search.each do |dir|
              next unless Dir.exist?(dir)

              candidate = Dir.children(dir).sort
                .map { |entry| File.join(dir, entry) }
                .find { |path| executable_file?(path) }
              return [candidate, url] if candidate
            end
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

        client_build_roots(root).each do |base|
          [File.join(base, "build", "web"), File.join(base, "web")].each do |dir|
            return dir if built_web_client_dir?(dir)
          end
        end

        nil
      end

      def ensure_prebuilt_client(
        web: false, desktop: false, desktop_experimental: false,
        ios_experimental: false, platform: nil, force: false
      )
        platform ||= host_platform_name
        return nil if platform.nil?

        cache_root = client_cache_root_for(platform)
        FileUtils.mkdir_p(cache_root)

        wanted_assets = []
        wanted_assets << { kind: :web, name: "#{ASSET_PREFIX}-web.tar.gz" } if web
        if desktop
          desktop_asset = desktop_asset_name_for(platform)
          return nil if desktop_asset.nil?
          wanted_assets << { kind: :desktop, name: desktop_asset, platform: platform }
        end
        if desktop_experimental
          return nil unless platform == "macos"

          wanted_assets << {
            kind: :desktop_experimental,
            name: EXPERIMENTAL_MACOS_ASSET,
            platform: platform
          }
        end
        if ios_experimental
          return nil unless platform == "macos"

          wanted_assets << {
            kind: :ios_experimental,
            name: EXPERIMENTAL_IOS_SIMULATOR_ASSET,
            platform: platform
          }
        end
        cache_ready = wanted_assets.empty? || prebuilt_assets_present?(
          cache_root,
          web: web,
          desktop: desktop,
          desktop_experimental: desktop_experimental,
          ios_experimental: ios_experimental,
          platform: platform
        )
        release = nil
        if !force && cache_ready
          ensure_client_manifest(cache_root, platform: platform)
          manifest = read_client_manifest(cache_root)
          return cache_root unless client_update_due?(manifest)

          release = fetch_release_for_version(wanted_assets: wanted_assets)
          if release.nil? || client_release_current?(manifest, release, wanted_assets)
            mark_client_update_checked(cache_root)
            return cache_root
          end

          force = true
        end

        release ||= fetch_release_for_version(wanted_assets: wanted_assets)
        return nil unless release

        assets = release.fetch("assets", [])
        asset_names = assets.map { |a| a["name"].to_s }
        installed_assets = []
        release_revision = client_release_revision(release)
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
            subdir = case wanted[:kind]
            when :web then "web"
            when :desktop then "desktop"
            when :desktop_experimental then "desktop-experimental"
            when :ios_experimental then "ios-experimental"
            end
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
              "download_url" => asset.fetch("browser_download_url"),
              "release_revision" => release_revision
            }
          end
        end

        if prebuilt_assets_present?(
          cache_root,
          web: web,
          desktop: desktop,
          desktop_experimental: desktop_experimental,
          ios_experimental: ios_experimental,
          platform: platform
        )
          write_client_manifest(cache_root, platform: platform, release: release, assets: installed_assets)
          return cache_root
        end

        nil
      rescue StandardError => e
        warn "Prebuilt client bootstrap failed: #{e.class}: #{e.message}"
        nil
      end

      # This decides both "the download installed correctly" and "the cache is
      # still usable, skip the network". It has to agree with what `ruflet run`
      # will actually accept later, or a half-extracted cache reports success
      # here and then fails to launch -- and, because a present cache short
      # circuits the download, never repairs itself without --force.
      def prebuilt_assets_present?(
        root, web:, desktop:, desktop_experimental: false,
        ios_experimental: false, platform: nil
      )
        ok_web = !web || built_web_client_dir?(File.join(root, "web"))
        ok_desktop = !desktop || prebuilt_desktop_present?(root, platform: platform)
        ok_desktop_experimental = !desktop_experimental ||
          prebuilt_experimental_desktop_present?(root, platform: platform)
        ok_ios_experimental = !ios_experimental || !experimental_ios_app_bundle(root).nil?
        ok_web && ok_desktop && ok_desktop_experimental && ok_ios_experimental
      end

      def experimental_ios_app_bundle(root)
        ios_root = File.join(root, "ios-experimental")
        return nil unless Dir.exist?(ios_root)

        Dir.glob(File.join(ios_root, "*.app")).sort.find do |app_bundle|
          File.file?(File.join(app_bundle, "Info.plist")) && ios_app_executable(app_bundle)
        end
      end

      def ios_app_executable(app_bundle)
        return nil unless Dir.exist?(app_bundle)

        Dir.children(app_bundle)
          .map { |entry| File.join(app_bundle, entry) }
          .find { |path| executable_file?(path) }
      end

      def booted_ios_simulator
        output, status = Open3.capture2e("xcrun", "simctl", "list", "devices", "booted", "--json")
        return nil unless status.success?

        devices = JSON.parse(output).fetch("devices", {})
        devices.each do |runtime, candidates|
          next unless runtime.to_s.include?("SimRuntime.iOS")

          match = Array(candidates).find do |device|
            device["state"] == "Booted" && device.fetch("isAvailable", true)
          end
          return match if match
        end
        nil
      rescue StandardError
        nil
      end

      def ios_bundle_identifier(app_bundle)
        plist = File.join(app_bundle, "Info.plist")
        output, status = Open3.capture2e(
          "/usr/bin/plutil", "-extract", "CFBundleIdentifier", "raw", "-o", "-", plist
        )
        status.success? ? output.strip : nil
      rescue StandardError
        nil
      end

      # The prebuilt client is whatever `ruflet build` produced from Ruflet
      # Explorer, so its bundle and binary carry that project's app name --
      # "Ruflet Explorer.app", not the old "ruflet_client.app". Match on shape
      # the way detect_desktop_client_command does rather than on a fixed name.
      def prebuilt_desktop_present?(root, platform: nil)
        platform ||= host_platform_name
        return false if platform.nil?

        desktop = File.join(root, "desktop")
        return false unless Dir.exist?(desktop)

        case platform
        when "macos"
          Dir.glob(File.join(desktop, "*.app")).any? { |app_bundle| macos_app_executable(app_bundle) }
        when "linux"
          Dir.children(desktop).any? { |entry| executable_file?(File.join(desktop, entry)) }
        when "windows"
          Dir.glob(File.join(desktop, "*.exe")).any? { |path| File.file?(path) }
        else
          false
        end
      end

      def prebuilt_experimental_desktop_present?(root, platform: nil)
        return false unless (platform || host_platform_name) == "macos"

        desktop = File.join(root, "desktop-experimental")
        return false unless Dir.exist?(desktop)

        Dir.glob(File.join(desktop, "*.app")).any? do |app_bundle|
          macos_app_executable(app_bundle)
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
        when "macos" then "#{ASSET_PREFIX}-macos-universal.zip"
        when "linux" then "#{ASSET_PREFIX}-linux-x64.tar.gz"
        when "windows" then "#{ASSET_PREFIX}-windows-x64.zip"
        end
      end

      def client_cache_root_for(platform)
        File.join(Dir.home, ".ruflet", "client", ruflet_version, platform.to_s)
      end

      def fetch_release_for_version(wanted_assets: [])
        releases = []
        channel = client_release_channel(wanted_assets: wanted_assets)
        if channel != "stable"
          rolling = release_by_tag(channel)
          releases << rolling if rolling && rolling_release_complete?(rolling)
        end
        releases << release_by_tag("v#{ruflet_version}")
        releases << release_by_tag(ruflet_version)
        releases << release_latest
        releases.compact.find { |release| release_has_wanted_assets?(release, wanted_assets) }
      end

      def client_release_channel(wanted_assets: [])
        default_channel = wanted_assets.any? do |wanted|
          %i[desktop_experimental ios_experimental].include?(wanted[:kind])
        end ? "prebuild-experimental" : "prebuild-main"
        value = ENV.fetch("RUFLET_CLIENT_CHANNEL", default_channel).to_s.strip
        value.empty? ? default_channel : value
      end

      def rolling_release_complete?(release)
        !channel_manifest_asset(release).nil?
      end

      # The manifest is written last, so its presence means the run finished
      # uploading every platform. Accept either naming for releases published
      # before the assets were renamed.
      def channel_manifest_asset(release)
        names = [CLIENT_CHANNEL_MANIFEST, LEGACY_CLIENT_CHANNEL_MANIFEST]
        release.fetch("assets", []).find { |asset| names.include?(asset["name"]) }
      end

      def release_has_wanted_assets?(release, wanted_assets)
        assets = release.fetch("assets", [])
        wanted_assets.all? do |wanted|
          assets.any? { |asset| asset["name"] == wanted[:name] } || fallback_release_asset(assets, wanted)
        end
      end

      def client_release_revision(release)
        source = channel_manifest_asset(release) || release
        [source["id"], source["updated_at"] || source["published_at"], source["size"]].compact.join(":")
      end

      def client_release_current?(manifest, release, wanted_assets)
        return false unless manifest

        revision = client_release_revision(release)
        targets = Array(manifest["targets"])
        wanted_assets.all? do |wanted|
          targets.any? do |target|
            target["kind"] == wanted[:kind].to_s &&
              (wanted[:platform].nil? || target["platform"] == wanted[:platform]) &&
              target["release_revision"] == revision
          end
        end
      end

      def client_update_due?(manifest)
        return false if ENV["RUFLET_CLIENT_AUTO_UPDATE"].to_s.match?(/\A(?:0|false|no|off)\z/i)
        return true unless manifest

        checked_at = manifest["checked_at"] || manifest["installed_at"]
        return true if checked_at.to_s.empty?

        Time.now.utc - Time.iso8601(checked_at) >= client_update_interval
      rescue ArgumentError
        true
      end

      def client_update_interval
        Integer(ENV.fetch("RUFLET_CLIENT_UPDATE_INTERVAL", DEFAULT_CLIENT_UPDATE_INTERVAL.to_s), 10).clamp(0, 7 * 24 * 60 * 60)
      rescue ArgumentError
        DEFAULT_CLIENT_UPDATE_INTERVAL
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
        return false unless n.include?(ASSET_PREFIX) || n.include?(LEGACY_ASSET_PREFIX)

        if kind == :web
          return n.include?("web") && (n.end_with?(".tar.gz") || n.end_with?(".zip"))
        end

        if kind == :ios_experimental
          return n.include?("ios") && n.include?("experimental") && n.include?("simulator") && n.end_with?(".zip")
        end

        if kind == :desktop_experimental
          return n.include?("macos") && n.include?("experimental") && n.end_with?(".zip")
        end

        case platform
        when "macos"
          n.include?("macos") && !n.include?("experimental") && n.end_with?(".zip")
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
        assets << { "kind" => "web", "platform" => platform, "asset_name" => nil } if built_web_client_dir?(File.join(root, "web"))
        if prebuilt_desktop_present?(root, platform: platform)
          assets << { "kind" => "desktop", "platform" => platform, "asset_name" => nil }
        end
        if prebuilt_experimental_desktop_present?(root, platform: platform)
          assets << { "kind" => "desktop_experimental", "platform" => platform, "asset_name" => nil }
        end
        if experimental_ios_app_bundle(root)
          assets << { "kind" => "ios_experimental", "platform" => platform, "asset_name" => nil }
        end
        return if assets.empty?

        write_client_manifest(root, platform: platform, release: nil, assets: assets)
      end

      def write_client_manifest(root, platform:, release:, assets:)
        FileUtils.mkdir_p(root)
        existing = read_client_manifest(root) || {}
        installed_targets = Array(existing["targets"])
        assets.each do |asset|
          installed_targets.reject! do |target|
            target["kind"] == asset["kind"] && target["platform"] == asset["platform"]
          end
          installed_targets << asset
        end
        payload = {
          "schema" => 2,
          "ruflet_version" => ruflet_version,
          "platform" => platform,
          "release_tag" => release && release["tag_name"] || existing["release_tag"],
          "release_revision" => release && client_release_revision(release) || existing["release_revision"],
          "released_at" => release && release["published_at"] || existing["released_at"],
          "checked_at" => Time.now.utc.iso8601,
          "installed_at" => Time.now.utc.iso8601,
          "targets" => installed_targets
        }
        File.write(client_manifest_path(root), JSON.pretty_generate(payload))
      end

      def mark_client_update_checked(root)
        manifest = read_client_manifest(root)
        return unless manifest

        manifest["checked_at"] = Time.now.utc.iso8601
        File.write(client_manifest_path(root), JSON.pretty_generate(manifest))
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
