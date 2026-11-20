# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Runs Flutter and the other external tools a build needs, with the
      # environment each one expects.
      module FlutterTooling
        # `flutter build` options whose value is a path. Flutter resolves a
        # relative one against its working directory, the client dir, while
        # Ruflet users mean the project (CLI-05). Inputs are files Flutter
        # reads; outputs are files or directories it writes.
        FLUTTER_INPUT_PATH_OPTIONS = %w[--dart-define-from-file --export-options-plist].freeze
        FLUTTER_OUTPUT_PATH_OPTIONS = %w[
          --split-debug-info --code-size-directory --performance-measurement-file
        ].freeze
        # `flutter build web`'s output directory: --output, its alias
        # --output-dir and its abbreviation -o. Flutter gives no other target
        # Ruflet builds this option.
        FLUTTER_WEB_OUTPUT_OPTIONS = %w[--output --output-dir].freeze
        FLUTTER_WEB_OUTPUT_ABBREVIATION = "-o"

        private

        # A copy of args in which a relative path given to a path-valued
        # Flutter option, in each spelling Flutter accepts (`--flag value`,
        # `--flag=value`, and for web `-o value` and `-ovalue`), is made
        # absolute against the project root when, and only when, the path
        # Flutter would use today is broken:
        # - an input is rewritten when it is not a file in the client dir
        #   (Flutter would stop with "not found") but is one in the project;
        # - an output is rewritten when it would be written inside the
        #   managed build/client, which a template refresh deletes, outside
        #   what the build exports from there, and when its project path lies
        #   inside the project but is neither the project root nor a
        #   directory holding build/client, nor inside build/client or a
        #   directory that export replaces.
        # Everything else is left as written: absolute paths; paths that
        # already leave build/client (such as `../../symbols`); outputs in a
        # client dir Ruflet does not manage (RUFLET_CLIENT_DIR,
        # ./ruflet_client); a missing or empty value, one that looks like a
        # flag, or a `~` no shell expanded; every other argument; and all
        # arguments after a bare `--`, which Flutter takes as positional.
        def resolve_flutter_path_args(args, root = Dir.pwd, client_dir: hidden_flutter_client_dir(root), platform: nil)
          # An ipa is built and exported as ios (see BuildCommand#command_build).
          platform = "ios" if platform == "ipa"
          kinds = flutter_path_option_kinds(platform)
          resolve = ->(kind, value) { flutter_path_value(kind, value, root, client_dir, platform) }
          resolved = []
          index = 0
          while index < args.length
            arg = args[index]
            if arg == "--"
              resolved.concat(args[index..])
              break
            end

            name, value = arg.split("=", 2)
            if (kind = kinds[arg])
              resolved << arg
              if index + 1 < args.length
                index += 1
                resolved << resolve.call(kind, args[index])
              end
            elsif value && name.start_with?("--") && (kind = kinds[name])
              resolved << "#{name}=#{resolve.call(kind, value)}"
            elsif kinds.key?(FLUTTER_WEB_OUTPUT_ABBREVIATION) && arg.start_with?(FLUTTER_WEB_OUTPUT_ABBREVIATION) &&
                arg.length > FLUTTER_WEB_OUTPUT_ABBREVIATION.length
              short = FLUTTER_WEB_OUTPUT_ABBREVIATION
              resolved << "#{short}#{resolve.call(:output, arg[short.length..])}"
            else
              resolved << arg
            end
            index += 1
          end
          resolved
        end

        def flutter_path_option_kinds(platform)
          kinds = FLUTTER_INPUT_PATH_OPTIONS.to_h { |name| [name, :input] }
          FLUTTER_OUTPUT_PATH_OPTIONS.each { |name| kinds[name] = :output }
          if platform == "web"
            FLUTTER_WEB_OUTPUT_OPTIONS.each { |name| kinds[name] = :output }
            kinds[FLUTTER_WEB_OUTPUT_ABBREVIATION] = :output
          end
          kinds
        end

        def flutter_path_value(kind, value, root, client_dir, platform)
          return value if value.empty? || value.start_with?("-", "~") || File.absolute_path?(value)

          client = File.expand_path(client_dir)
          if kind == :input
            flutter_input_path(value, root, client)
          else
            flutter_output_path(value, root, client, platform)
          end
        end

        def flutter_input_path(value, root, client)
          return value if File.file?(File.expand_path(value, client))

          project = File.expand_path(value, root)
          File.file?(project) ? project : value
        end

        def flutter_output_path(value, root, client, platform)
          return value unless client == File.expand_path(hidden_flutter_client_dir(root))

          today = File.expand_path(value, client)
          return value unless path_within?(today, client)

          exports = exports_for(platform)
          return value if exports.keys.any? { |source| path_within?(today, File.join(client, "build", source)) }

          project = File.expand_path(value, root)
          return value unless path_within?(project, File.expand_path(root))
          return value if path_within?(project, client) || path_within?(client, project)
          return value if exports.values.any? { |target| path_within?(project, File.join(user_build_root(root), target)) }

          project
        end

        def path_within?(path, dir)
          path == dir || path.start_with?(File.join(dir, ""))
        end

        def build_tool_env(env, platform, client_dir = nil)
          return env unless %w[ios macos].include?(platform)

          apple_env = unbundled_command_env(env)
          apple_env["PATH"] = apple_build_path(apple_env["PATH"])
          install_apple_pod_shim(client_dir, apple_env) if client_dir
          apple_env
        end

        def install_tool_env(env, client_dir)
          return build_tool_env(env, inferred_install_platform, client_dir) if inferred_install_platform

          command_env = unbundled_command_env(env)
          command_env["PATH"] = apple_build_path(command_env["PATH"])
          install_apple_pod_shim(client_dir, command_env)
          command_env
        end

        def ensure_flutter_platform_artifacts(client_dir, platform, env, flutter, verbose: false)
          precache_flags = flutter_precache_flags(platform)
          return true if precache_flags.empty?

          build_note("Preparing Flutter #{platform} platform artifacts")
          build_log(verbose, "running flutter precache #{precache_flags.join(' ')}")
          ok = run_external_command(env, flutter, "precache", *precache_flags, chdir: client_dir, unbundled: true)
          return true if ok

          warn "Flutter platform artifact setup failed for #{platform}"
          false
        end

        def flutter_precache_flags(platform)
          case platform
          when "apk", "android", "aab", "appbundle"
            ["--android"]
          when "ios"
            ["--ios"]
          when "macos"
            ["--macos"]
          when "windows"
            ["--windows"]
          when "linux"
            ["--linux"]
          when "web"
            ["--web"]
          else
            []
          end
        end

        def ensure_native_build_dependencies(client_dir, platform, env, verbose: false)
          case platform
          when "ios"
            ensure_cocoapods_install(client_dir, "ios", env, verbose: verbose)
          when "macos"
            ok = true
            ok &&= ensure_cocoapods_install(client_dir, "ios", env, verbose: verbose)
            ok &&= ensure_cocoapods_install(client_dir, "macos", env, verbose: verbose)
            ok
          else
            true
          end
        end

        def unbundled_command_env(env)
          env.reject { |key, _value| key.start_with?("BUNDLE_") || key == "RUBYOPT" || key == "RUBYLIB" || key.start_with?("GEM_") }
        end

        def run_external_command(env, *cmd, chdir:, unbundled: false)
          if unbundled && defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
            Bundler.with_unbundled_env do
              system(env, *cmd, chdir: chdir)
            end
          else
            system(env, *cmd, chdir: chdir)
          end
        end

        def flutter_build_command(platform)
          case platform
          when "apk", "android"
            ["build", "apk"]
          when "aab", "appbundle"
            ["build", "appbundle"]
          when "ios"
            ["build", "ios"]
          when "ipa"
            ["build", "ipa"]
          when "web"
            ["build", "web"]
          when "macos"
            ["build", "macos"]
          when "windows"
            ["build", "windows"]
          when "linux"
            ["build", "linux"]
          else
            nil
          end
        end

        # The build target, downcased and removed from args ("" when there is
        # none). It is the first argument, as it always was. When that is a
        # flag (`ruflet build --release apk`), it is the one argument that
        # names a target, so the flags before it reach Flutter as they would
        # after it. Two such arguments (`--flavor web apk`) are refused rather
        # than guessed at: which one is a flag's value is Flutter's to know.
        # Nothing after `--` is a target: `build -- apk` is still the
        # unsupported target "--", and `build --release -- apk` has none. A
        # bare `-` is an argument, not a flag (Commands.flag?), so `build -
        # apk` is still the unsupported target "-".
        def extract_build_target!(args)
          first = args.first
          return (args.shift || "").downcase unless first && Commands.flag?(first) && first != "--"

          stop = args.index("--") || args.length
          positionals = (0...stop).reject { |index| Commands.flag?(args[index]) }
          targets = positionals.select { |index| flutter_build_command(args[index].downcase) }
          if targets.length > 1
            names = targets.map { |index| args[index] }.join(", ")
            raise Commands::UsageError, "more than one argument names a build target (#{names}); put the target first"
          end

          index = targets.first || positionals.first
          return "" unless index

          args.delete_at(index).downcase
        end

        def ios_device_build_needs_codesign_flag?(platform, build_args)
          return false unless platform == "ios"
          return false if build_args.include?("--simulator")
          return false if build_args.include?("--no-codesign")
          return false if build_args.include?("--codesign")

          true
        end
      end
    end
  end
end
