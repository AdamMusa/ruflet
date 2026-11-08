# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Runs CocoaPods for the iOS and macOS hosts with a working `pod`.
        module Podfile
          private

          def ensure_cocoapods_install(client_dir, platform_dir, env, verbose: false)
            pod_dir = File.join(client_dir, platform_dir)
            return true unless Dir.exist?(pod_dir)
            return true unless File.file?(File.join(pod_dir, "Podfile"))

            build_note("Running CocoaPods install for #{platform_dir}")
            build_log(verbose, "pod install in #{pod_dir}")
            ok =
              if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
                Bundler.with_unbundled_env do
                  run_external_command(unbundled_command_env(env), "pod", "install", chdir: pod_dir, unbundled: false)
                end
              else
                run_external_command(unbundled_command_env(env), "pod", "install", chdir: pod_dir, unbundled: false)
              end
            return true if ok

            warn "CocoaPods install failed for #{platform_dir}"
            warn "Make sure `pod` is installed and working for the Ruby used by Flutter."
            false
          end

          def apple_build_path(existing_path)
            segments = existing_path.to_s.split(File::PATH_SEPARATOR)
            segments.reject! { |segment| segment.include?("/.gem/ruby/") && segment.end_with?("/bin") }

            preferred = []
            preferred << "/opt/homebrew/bin" if File.executable?("/opt/homebrew/bin/pod")
            preferred << "/usr/local/bin" if File.executable?("/usr/local/bin/pod")

            (preferred + segments).uniq.join(File::PATH_SEPARATOR)
          end

          def install_apple_pod_shim(client_dir, env)
            pod_executable = resolve_working_pod_executable
            return unless pod_executable

            shim_dir = File.join(client_dir, ".ruflet", "bin")
            FileUtils.mkdir_p(shim_dir)
            shim_path = File.join(shim_dir, "pod")
            write_text_file(
              shim_path,
              <<~SH
                #!/bin/sh
                exec "#{pod_executable}" "$@"
              SH
            )
            FileUtils.chmod("+x", shim_path)
            env["PATH"] = ([shim_dir] + env["PATH"].to_s.split(File::PATH_SEPARATOR)).uniq.join(File::PATH_SEPARATOR)
            env["COCOAPODS_DISABLE_STATS"] = "true"
            env["GEM_HOME"] = nil
            env["GEM_PATH"] = nil
            env["GEM_ROOT"] = nil
          end

          def resolve_working_pod_executable
            return "/opt/homebrew/bin/pod" if File.executable?("/opt/homebrew/bin/pod")
            return "/usr/local/bin/pod" if File.executable?("/usr/local/bin/pod")

            nil
          end
        end
      end
    end
  end
end
