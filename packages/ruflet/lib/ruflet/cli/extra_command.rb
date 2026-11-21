# frozen_string_literal: true

require "optparse"

module Ruflet
  module CLI
    module ExtraCommand
      include FlutterSdk
      include NewCommand

      def command_create(args)
        command_new(args)
      end

      def command_doctor(args)
        verbose = args.delete("--verbose") || args.delete("-v")
        fix = args.delete("--fix")
        strict = args.delete("--strict")
        client_dir = detect_client_dir
        template_root =
          if fix
            ensure_cached_ruflet_client_template!(force: true, verbose: !!verbose)
          else
            resolve_ruflet_client_template_root
          end
        puts "Ruflet doctor"
        puts "  Ruby: #{RUBY_VERSION}"
        puts "  Flutter host target: #{flutter_host || 'unsupported'}"
        if template_root
          puts "  Template: #{template_root}"
          revision = cached_template_revision if respond_to?(:cached_template_revision, true)
          puts "  Template revision: #{revision}" if revision
          surface_ok = TemplateSurfaceCheck.check(self, template_root, strict: !!strict, config: -> { doctor_project_config })
        elsif fix
          warn "  Template: missing"
          warn "Failed to fetch the Ruflet Flutter template from GitHub."
          return 1
        else
          warn "  Template: missing"
          warn "Run `ruflet doctor --fix` to fetch the Flutter template from GitHub."
        end
        puts "  Ruby runtime: pub.dev package"
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
        status = system_exit_code(system(tools[:env], tools[:flutter], "doctor", *(verbose ? ["-v"] : [])))
        return 1 if surface_ok == false && status.zero?

        status
      end

      def command_devices(args)
        tools = ensure_flutter!("devices")
        system_exit_code(system(tools[:env], tools[:flutter], "devices", *args))
      end

      def command_emulators(args)
        action = nil
        emulator_id = nil
        verbose = false
        cold = false
        parser = OptionParser.new do |o|
          # -c and --c reached --create before --cold made them ambiguous.
          o.on("--create", "-c", "--c") { action = "create" }
          o.on("--delete") { action = "delete" }
          o.on("--start") { action = "start" }
          o.on("--emulator ID") { |v| emulator_id = v }
          o.on("--cold") { cold = true }
          o.on("-v", "--verbose") { verbose = true }
          o.on("-h", "--help") { raise Commands::HelpRequested }
        end
        # Parse first: a bad flag is reported before Flutter is looked up.
        parser.parse!(args)
        raise Commands::UsageError, "--cold needs --start --emulator ID" if cold && action != "start"

        # Answer what needs no Flutter before ensure_flutter!, which may
        # install an SDK (or exit) on a machine without one.
        if %w[create delete].include?(action)
          warn "ruflet emulators --#{action} is not implemented yet. Use your platform tools."
          return 1
        end
        if action == "start" && !emulator_id
          warn "Missing --emulator for start"
          return 1
        end

        tools = ensure_flutter!("emulators")
        cmd = [tools[:flutter], "emulators"]
        cmd += ["--launch", emulator_id] if action == "start"
        cmd << "--cold" if cold
        cmd << "-v" if verbose
        system_exit_code(system(tools[:env], *cmd))
      rescue Commands::HelpRequested, Commands::UsageError => e
        Commands.report_stop("emulators", e)
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
          # --device and -d already reached --device-id as abbreviations.
          o.on("--device-id ID", "--device ID") { |v| options[:device_id] = v }
          o.on("--release") { options[:release] = true }
          o.on("-v", "--verbose") { options[:verbose] = true }
          o.on("--web-renderer NAME") { |v| options[:web_renderer] = v }
          o.on("-h", "--help") { raise Commands::HelpRequested }
        end
        parser.parse!(args)

        options[:platform] ||= args.shift
        client_dir = detect_client_dir
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or let Ruflet manage the client under ./build/client"
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

        system_exit_code(system(tools[:env], *cmd, chdir: client_dir))
      rescue Commands::HelpRequested => e
        Commands.report_stop("debug", e)
      end

      private

      # The project's ruflet.yaml/services.yaml, when doctor runs in one; its
      # extensions are checked against the template. Read only when the
      # template lacks a bundled package, and quietly: doctor does not report
      # a config it cannot parse.
      def doctor_project_config
        return nil unless %w[ruflet.yaml ruflet.yml services.yaml].any? { |name| File.file?(name) }
        return nil unless respond_to?(:load_ruflet_config, true)

        stderr = $stderr
        File.open(File::NULL, "w") do |null|
          $stderr = null
          send(:load_ruflet_config)
        end
      rescue StandardError
        nil
      ensure
        $stderr = stderr if stderr
      end

      # The exit code of a command run with Kernel#system. system's own result
      # decides success: $? is per thread and still describes the previous
      # child when system spawned none (a stubbed system in a test), so
      # reading $? alone could report someone else's status. $? only supplies
      # the code of a command that failed.
      def system_exit_code(ok)
        return 0 if ok

        code = $?&.exitstatus
        code.nil? || code.zero? ? 1 : code
      end

      def resolve_ruby_runtime_root
        env_path = ENV["RUFLET_RUBY_RUNTIME_PATH"].to_s.strip
        candidates = []
        candidates << File.expand_path(env_path) unless env_path.empty?
        candidates << File.expand_path("../../../../../ruby_runtime", __dir__)
        candidates << cached_ruby_runtime_root
        candidates.find { |path| File.file?(File.join(path, "pubspec.yaml")) }
      end

      def detect_client_dir
        env_dir = ENV["RUFLET_CLIENT_DIR"]
        return env_dir if env_dir && Dir.exist?(env_dir)

        hidden = File.expand_path(File.join("build", "client"), Dir.pwd)
        return hidden if Dir.exist?(hidden)

        local = File.expand_path("ruflet_client", Dir.pwd)
        return local if Dir.exist?(local)

        template = File.expand_path("templates/ruflet_flutter_template", Dir.pwd)
        return template if Dir.exist?(template)

        nil
      end

    end
  end
end
