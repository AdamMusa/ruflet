# frozen_string_literal: true

module Ruflet
  module Rails
    class Railtie < ::Rails::Railtie
      # Insert the Ruflet WebSocket middleware into the Rack stack.
      # If Ruflet::Rails.config.app_file is set (via an initializer), the
      # middleware auto-handles WebSocket upgrades at config.ws_path — no
      # `mount` line needed in config/routes.rb.
      initializer "ruflet_rails.middleware", after: :load_config_initializers do |app|
        ruflet_config = Ruflet::Rails.config

        if ruflet_config.app_file
          app.middleware.use(
            Ruflet::Rails::Protocol::Middleware,
            path: ruflet_config.ws_path,
            entrypoint_path: ruflet_config.app_file.to_s
          )
        else
          # Fallback: insert context-only middleware so manual `mount` still works.
          app.middleware.use Ruflet::Rails::Protocol::Middleware
        end
      end

      initializer "ruflet_rails.desktop_launcher", after: :load_config_initializers do |_app|
        next unless defined?(::Rails.root)

        Ruflet::Rails::DesktopLauncher.launch_once(root: ::Rails.root)
      end

      rake_tasks do
        namespace :ruflet do
          desc "Build Ruflet client for this Rails app. Usage: rake ruflet:build[platform]"
          task :build, [:platform] do |_task, args|
            platform = args[:platform].to_s.strip.downcase
            build_args = Ruflet::Rails::InstallSupport.build_args_for_platform(platform)
            if build_args.empty?
              warn "Usage: rake ruflet:build[apk|android|ios|aab|web|desktop|macos|windows|linux]"
              next
            end

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_build(build_args)
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?
          end

          desc "Download/update prebuilt Ruflet clients from GitHub releases. Usage: rake ruflet:update[target]"
          task :update, [:target] do |_task, args|
            target = args[:target].to_s.strip
            if target.empty?
              warn "Usage: rake ruflet:update[desktop|all]"
              next
            end

            require "ruflet/cli"
            exit_code = Dir.chdir(::Rails.root) do
              Ruflet::CLI.command_update([target])
            end
            raise SystemExit, exit_code unless exit_code.to_i.zero?
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
