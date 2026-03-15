# frozen_string_literal: true

require "optparse"

module Ruflet
  module CLI
    module UpdateCommand
      include RunCommand

      VALID_UPDATE_PLATFORMS = %w[macos linux windows].freeze

      def command_update(args)
        options = {
          web: false,
          desktop: false,
          check: false,
          force: false,
          platform: nil
        }

        parser = OptionParser.new do |o|
          o.on("--web") { options[:web] = true }
          o.on("--desktop") { options[:desktop] = true }
          o.on("--check") { options[:check] = true }
          o.on("--force") { options[:force] = true }
          o.on("--platform PLATFORM") { |value| options[:platform] = value.to_s.downcase }
        end
        parser.parse!(args)

        args.each do |arg|
          case arg.to_s.downcase
          when "web"
            options[:web] = true
          when "desktop"
            options[:desktop] = true
          when "all"
            options[:web] = true
            options[:desktop] = true
          when "check"
            options[:check] = true
          else
            warn "Unknown update target: #{arg}"
            return 1
          end
        end

        platform = options[:platform] || host_platform_name
        if platform.nil? || !VALID_UPDATE_PLATFORMS.include?(platform)
          warn "Unsupported or missing platform. Use --platform macos|linux|windows."
          return 1
        end

        if !options[:web] && !options[:desktop]
          options[:web] = true
          options[:desktop] = true
        end

        targets = []
        targets << :web if options[:web]
        targets << :desktop if options[:desktop]

        return check_client_updates(targets, platform: platform) if options[:check]

        targets.each do |target|
          root =
            if target == :web
              ensure_prebuilt_client(web: true, platform: platform, force: options[:force])
            else
              ensure_prebuilt_client(desktop: true, platform: platform, force: options[:force])
            end
          unless root
            warn "Failed to update #{target} client for #{platform}"
            return 1
          end

          manifest = read_client_manifest(root)
          release_label = manifest && manifest["release_tag"] ? manifest["release_tag"] : "unknown release"
          puts "Updated #{target} client for #{platform} at #{root} (#{release_label})"
        end

        0
      end

      private

      def check_client_updates(targets, platform:)
        root = client_cache_root_for(platform)
        manifest = read_client_manifest(root)

        puts "Ruflet client cache: #{root}"
        puts "Platform: #{platform}"
        puts "Ruflet version: #{ruflet_version}"
        puts "Release tag: #{manifest && manifest['release_tag'] ? manifest['release_tag'] : 'not installed'}"

        installed = true
        targets.each do |target|
          present =
            if target == :web
              File.file?(File.join(root, "web", "index.html"))
            else
              prebuilt_desktop_present?(root, platform: platform)
            end
          installed &&= present
          puts "#{target}: #{present ? 'installed' : 'missing'}"
        end

        installed ? 0 : 1
      end
    end
  end
end
