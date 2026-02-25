# frozen_string_literal: true

require "optparse"
require "rbconfig"
require "socket"

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

        puts "Requested port 8550 is busy; bound to #{selected_port}" if selected_port != 8550
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
      end

      private

      def resolve_script(token)
        path = File.expand_path(token, Dir.pwd)
        return path if File.file?(path)

        candidate = File.expand_path("#{token}.rb", Dir.pwd)
        return candidate if File.file?(candidate)

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
