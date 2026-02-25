# frozen_string_literal: true

module Ruflet
  module CLI
    module BuildCommand
      def command_build(args)
        platform = (args.shift || "").downcase
        if platform.empty?
          warn "Usage: ruflet build <apk|ios|aab|web|macos|windows|linux>"
          return 1
        end

        flutter_cmd = flutter_build_command(platform)
        unless flutter_cmd
          warn "Unsupported build target: #{platform}"
          return 1
        end

        client_dir = detect_flutter_client_dir
        unless client_dir
          warn "Could not find Flutter client directory."
          warn "Set RUFLET_CLIENT_DIR or place client at ./ruflet_client"
          return 1
        end

        ok = system(*flutter_cmd, chdir: client_dir)
        ok ? 0 : 1
      end

      private

      def detect_flutter_client_dir
        env_dir = ENV["RUFLET_CLIENT_DIR"]
        return env_dir if env_dir && Dir.exist?(env_dir)

        local = File.expand_path("ruflet_client", Dir.pwd)
        return local if Dir.exist?(local)

        nil
      end

      def flutter_build_command(platform)
        case platform
        when "apk", "android"
          ["flutter", "build", "apk"]
        when "aab", "appbundle"
          ["flutter", "build", "appbundle"]
        when "ios"
          ["flutter", "build", "ios", "--no-codesign"]
        when "web"
          ["flutter", "build", "web"]
        when "macos"
          ["flutter", "build", "macos"]
        when "windows"
          ["flutter", "build", "windows"]
        when "linux"
          ["flutter", "build", "linux"]
        else
          nil
        end
      end
    end
  end
end
