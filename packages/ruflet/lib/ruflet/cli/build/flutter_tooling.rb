# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      # Runs Flutter and the other external tools a build needs, with the
      # environment each one expects.
      module FlutterTooling
        # `flutter build` options whose value is a path. Flutter resolves them
        # against its working directory, which is build/client; Ruflet users
        # mean the project (CLI-05). -o abbreviates --output.
        FLUTTER_PATH_OPTIONS = %w[
          --dart-define-from-file --split-debug-info --export-options-plist
          --code-size-directory --performance-measurement-file --output --output-dir
        ].freeze
        FLUTTER_PATH_ABBREVIATIONS = %w[-o].freeze

        private

        # A copy of args with the value of every FLUTTER_PATH_OPTIONS flag, in
        # each spelling Flutter accepts (`--flag value`, `--flag=value`,
        # `-o value`, `-ovalue`), made absolute against the project root.
        # Absolute paths are untouched, and so is a value Ruflet cannot
        # resolve: a missing or empty one, one that looks like a flag, or a
        # `~` no shell expanded. Flutter reports those as it did before.
        def resolve_flutter_path_args(args, root = Dir.pwd)
          resolved = []
          index = 0
          while index < args.length
            arg = args[index]
            name, value = arg.split("=", 2)
            if FLUTTER_PATH_OPTIONS.include?(arg) || FLUTTER_PATH_ABBREVIATIONS.include?(arg)
              resolved << arg
              if index + 1 < args.length
                index += 1
                resolved << project_path(args[index], root)
              end
            elsif value && FLUTTER_PATH_OPTIONS.include?(name)
              resolved << "#{name}=#{project_path(value, root)}"
            elsif (abbreviation = FLUTTER_PATH_ABBREVIATIONS.find { |short| arg.start_with?(short) && arg.length > short.length })
              resolved << "#{abbreviation}#{project_path(arg[abbreviation.length..], root)}"
            else
              resolved << arg
            end
            index += 1
          end
          resolved
        end

        def project_path(value, root)
          return value if value.empty? || value.start_with?("-", "~")
          return value if File.absolute_path?(value)

          File.expand_path(value, root)
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
        def extract_build_target!(args)
          first = args.first
          return (args.shift || "").downcase unless first&.start_with?("-")

          positionals = args.each_index.reject { |index| args[index].start_with?("-") }
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
