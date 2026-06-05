# frozen_string_literal: true

module Ruflet
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "ruflet_rails.middleware" do |app|
        app.middleware.use Ruflet::Rails::Protocol::Middleware
      end

      initializer "ruflet_rails.desktop_launcher", after: :load_config_initializers do |_app|
        next unless defined?(::Rails.root)

        Ruflet::Rails::DesktopLauncher.launch_once(root: ::Rails.root)
      end

      rake_tasks do
        namespace :ruflet do
          desc "Build Ruflet client for this Rails app. Usage: rake ruflet:build[web]"
          task :build, [:platform] do |_task, args|
            requested_platform = args[:platform].to_s.strip.downcase
            build_args = Ruflet::Rails::InstallSupport.build_args_for_platform(requested_platform)
            platform = build_args.first
            if platform.to_s.empty?
              warn "Usage: rake ruflet:build[apk|android|ios|aab|web|desktop|macos|windows|linux]"
              next
            end

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_build(build_args)
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?

            if platform == "web"
              published = Ruflet::Rails::InstallSupport.publish_web_build(::Rails.root.to_s)
              if published
                puts "Ruflet web client published at /#{Ruflet::Rails::InstallSupport.default_web_public_path}/"
              else
                warn "Ruflet web build completed, but build/web was not found to publish."
              end
            end
          end

          desc "Download/update prebuilt Ruflet clients from GitHub releases. Usage: rake ruflet:update[web|desktop|all]"
          task :update, [:target] do |_task, args|
            target = args[:target].to_s.strip
            if target.empty?
              warn "Usage: rake ruflet:update[web|desktop|all]"
              next
            end
            normalized_target = target.downcase
            platform = Ruflet::Rails::InstallSupport.host_desktop_platform

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_update([target])
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?

            if %w[web all].include?(normalized_target)
              published = Ruflet::Rails::InstallSupport.publish_prebuilt_web_client(
                ::Rails.root.to_s,
                platform: platform
              )
              if published
                puts "Ruflet web client published at /#{Ruflet::Rails::InstallSupport.default_web_public_path}/"
              else
                warn "Ruflet web client downloaded, but no prebuilt web index.html was found to publish."
              end
            end
          end

          desc "Install the last built Ruflet mobile app onto a device. Usage: rake ruflet:install[DEVICE_ID]"
          task :install, [:device] do |_task, args|
            argv = []
            device = args[:device].to_s.strip
            argv += ["--device", device] unless device.empty?

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_install(argv)
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?
          end
        end
      end
    end
  end
end
