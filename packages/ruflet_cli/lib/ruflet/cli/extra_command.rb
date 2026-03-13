# frozen_string_literal: true

require "optparse"

module Ruflet
  module CLI
    module ExtraCommand
      include FlutterSdk

      def command_create(args)
        command_new(args)
      end

      def command_doctor(args)
        verbose = args.delete("--verbose") || args.delete("-v")
        fix = args.delete("--fix")
        client_dir = detect_client_dir
        puts "Ruflet doctor"
        puts "  Ruby: #{RUBY_VERSION}"
        puts "  Flutter host target: #{flutter_host || 'unsupported'}"
        if fix
          tools = ensure_flutter!("doctor", client_dir: client_dir, auto_install: true)
        else
          tools = flutter_tools(client_dir: client_dir, auto_install: false)
          unless tools
            warn "  Flutter: missing"
            warn "Run `ruflet doctor --fix` to install the host-platform Flutter SDK from .fvmrc."
            return 1
          end
        end
        puts "  Flutter: #{flutter_version_summary(tools)}"
        ok = system(tools[:env], tools[:flutter], "doctor", *(verbose ? ["-v"] : []))
        status = $?.exitstatus if $?
        status ||= ok ? 0 : 1
        status
      end

      def command_devices(args)
        tools = ensure_flutter!("devices")
        system(tools[:env], tools[:flutter], "devices", *args)
        $?.exitstatus || 1
      end

      def command_emulators(args)
        tools = ensure_flutter!("emulators")
        action = nil
        emulator_id = nil
        verbose = false
        parser = OptionParser.new do |o|
          o.on("--create") { action = "create" }
          o.on("--delete") { action = "delete" }
          o.on("--start") { action = "start" }
          o.on("--emulator ID") { |v| emulator_id = v }
          o.on("-v", "--verbose") { verbose = true }
        end
        parser.parse!(args)

        case action
        when "start"
          unless emulator_id
            warn "Missing --emulator for start"
            return 1
          end
          cmd = [tools[:flutter], "emulators", "--launch", emulator_id]
          cmd << "-v" if verbose
          system(tools[:env], *cmd)
          $?.exitstatus || 1
        when "create", "delete"
          warn "ruflet emulators --#{action} is not implemented yet. Use your platform tools."
          1
        else
          cmd = [tools[:flutter], "emulators"]
          cmd << "-v" if verbose
          system(tools[:env], *cmd)
          $?.exitstatus || 1
        end
      end

      def command_debug(args)
        options = {
          platform: nil,
          device_id: nil,
          release: false,
          verbose: false,
          web_renderer: nil
        }
        parser = OptionParser.new do |o|
          o.on("--platform NAME") { |v| options[:platform] = v }
          o.on("--device-id ID") { |v| options[:device_id] = v }
          o.on("--release") { options[:release] = true }
          o.on("-v", "--verbose") { options[:verbose] = true }
          o.on("--web-renderer NAME") { |v| options[:web_renderer] = v }
        end
        parser.parse!(args)

        options[:platform] ||= args.shift
        client_dir = detect_client_dir
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or place client at ./ruflet_client"
          warn "`ruflet debug` requires Flutter client source code."
          warn "For prebuilt clients, use: `ruflet run --web` or `ruflet run --desktop`."
          return 1
        end

        tools = ensure_flutter!("debug", client_dir: client_dir)
        cmd = [tools[:flutter], "run"]
        cmd << "--release" if options[:release]
        cmd << "-v" if options[:verbose]
        cmd += ["--web-renderer", options[:web_renderer]] if options[:web_renderer]

        if options[:device_id]
          cmd += ["-d", options[:device_id]]
        else
          case options[:platform]
          when "web"
            cmd += ["-d", "chrome"]
          when "macos", "windows", "linux"
            cmd += ["-d", options[:platform]]
          when "ios", "android"
            # let flutter pick the default device
          end
        end

        system(tools[:env], *cmd, chdir: client_dir)
        $?.exitstatus || 1
      end

      private

      def detect_client_dir
        env_dir = ENV["RUFLET_CLIENT_DIR"]
        return env_dir if env_dir && Dir.exist?(env_dir)

        local = File.expand_path("ruflet_client", Dir.pwd)
        return local if Dir.exist?(local)

        template = File.expand_path("templates/ruflet_flutter_template", Dir.pwd)
        return template if Dir.exist?(template)

        nil
      end

    end
  end
end
