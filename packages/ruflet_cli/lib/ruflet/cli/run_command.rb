# frozen_string_literal: true

require "optparse"
require "rbconfig"
require "socket"
require "timeout"

module Ruflet
  module CLI
    module RunCommand
      def command_run(args)
        options = { target: "mobile" }
        parser = OptionParser.new do |o|
          o.on("--web") { options[:target] = "web" }
          o.on("--mobile") { options[:target] = "mobile" }
          o.on("--desktop") { options[:target] = "desktop" }
        end
        parser.parse!(args)

        script_token = args.shift || "main"
        script_path = resolve_script(script_token)
        unless script_path
          warn "Script not found: #{script_token}"
          warn "Expected: ./#{script_token}.rb, ./#{script_token}, or explicit file path."
          return 1
        end

        selected_port = find_available_port(8550)
        env = {
          "RUFLET_TARGET" => options[:target],
          "RUFLET_SUPPRESS_SERVER_BANNER" => "1",
          "RUFLET_PORT" => selected_port.to_s
        }

        print_run_banner(target: options[:target], port: selected_port)
        print_mobile_qr_hint(port: selected_port) if options[:target] == "mobile"

        cmd =
          if File.file?(File.expand_path("Gemfile", Dir.pwd))
            env["BUNDLE_PATH"] = "vendor/bundle"
            env["BUNDLE_DISABLE_SHARED_GEMS"] = "true"
            bundle_ready = system(env, "bundle", "check", out: File::NULL, err: File::NULL)
            return 1 unless bundle_ready || system(env, "bundle", "install")

            ["bundle", "exec", RbConfig.ruby, script_path]
          else
            [RbConfig.ruby, script_path]
          end

        child_pid = Process.spawn(env, *cmd, pgroup: true)
        launched_client_pid = launch_target_client(options[:target], selected_port)
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

        if defined?(launched_client_pid) && launched_client_pid
          begin
            Process.kill("TERM", launched_client_pid)
          rescue Errno::ESRCH
            nil
          end
        end
      end

      private

      def resolve_script(token)
        path = File.expand_path(token, Dir.pwd)
        return path if File.file?(path)

        candidate = File.expand_path("#{token}.rb", Dir.pwd)
        return candidate if File.file?(candidate)

        nil
      end

      def print_run_banner(target:, port:)
        if port != 8550
          puts "Requested port 8550 is busy; bound to #{port}"
        end
        if target == "desktop"
          puts "Ruflet desktop URL: http://localhost:#{port}"
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
        end
      end

      def launch_web_client(port)
        web_dir = detect_web_client_dir
        unless web_dir
          warn "Web client build not found."
          warn "Build it first: ruflet build web"
          return nil
        end

        web_port = find_available_port(port + 1)
        pid = Process.spawn("python3", "-m", "http.server", web_port.to_s, "--bind", "127.0.0.1", chdir: web_dir, out: File::NULL, err: File::NULL)
        Process.detach(pid)
        wait_for_server_boot(web_port)
        open_in_browser("http://localhost:#{web_port}")
        puts "Ruflet web client: http://localhost:#{web_port}"
        puts "Ruflet backend ws: ws://localhost:#{port}/ws"
        pid
      rescue Errno::ENOENT
        warn "python3 is required to host web client locally."
        warn "Install Python 3 and rerun."
        nil
      rescue StandardError => e
        warn "Failed to launch web client: #{e.class}: #{e.message}"
        nil
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
        pid
      rescue StandardError => e
        warn "Failed to launch desktop client: #{e.class}: #{e.message}"
        warn "Start it manually with URL: #{url}"
        nil
      end

      def detect_desktop_client_command(url)
        root = ENV["RUFLET_CLIENT_DIR"]
        root = File.expand_path("ruflet_client", Dir.pwd) if root.to_s.strip.empty?
        return nil unless Dir.exist?(root)

        host_os = RbConfig::CONFIG["host_os"]
        if host_os.match?(/darwin/i)
          release_bin = File.join(root, "build", "macos", "Build", "Products", "Release", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
          debug_bin = File.join(root, "build", "macos", "Build", "Products", "Debug", "ruflet_client.app", "Contents", "MacOS", "ruflet_client")
          executable = [release_bin, debug_bin].find { |p| File.file?(p) && File.executable?(p) }
          return [executable, url] if executable
        elsif host_os.match?(/mswin|mingw|cygwin/i)
          exe = File.join(root, "build", "windows", "x64", "runner", "Release", "ruflet_client.exe")
          return [exe, url] if File.file?(exe)
        else
          direct = File.join(root, "build", "linux", "x64", "release", "bundle", "ruflet_client")
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
        return nil unless Dir.exist?(root)

        built = File.join(root, "build", "web")
        return built if Dir.exist?(built) && File.file?(File.join(built, "index.html"))

        nil
      end

      def print_mobile_qr_hint(port: 8550)
        host = best_lan_host
        payload = "http://#{host}:#{port}"

        puts
        puts "Ruflet mobile connect URL:"
        puts "  #{payload}"
        puts "Ruflet server ws URL:"
        puts "  ws://0.0.0.0:#{port}/ws"
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
          rescue Errno::EADDRINUSE
            port += 1
          end
        end

        start_port
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
