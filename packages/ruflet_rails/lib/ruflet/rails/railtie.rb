# frozen_string_literal: true

module Ruflet
  module Rails
    class Railtie < ::Rails::Railtie
      # Make the native view helpers available in every .erb template.
      initializer "ruflet_rails.view_helpers" do
        ActiveSupport.on_load(:action_view) do
          include Ruflet::Rails::ViewHelpers
          include Ruflet::Rails::HtmlDsl::ViewHelpers
        end
      end

      # ruflet_native_request? / render_native in every controller, so an
      # action can answer the native client in one cycle instead of two.
      initializer "ruflet_rails.controller_helpers" do
        ActiveSupport.on_load(:action_controller) do
          include Ruflet::Rails::ControllerHelpers
        end
      end

      initializer "ruflet_rails.desktop_launcher", after: :load_config_initializers do |_app|
        next unless defined?(::Rails.root)

        # Prefer config.backend_url over ruflet.yaml — no yaml needed in Rails.
        url_override = Ruflet::Rails.config.backend_url.to_s.strip
        env_override = url_override.empty? ? ENV.to_h : ENV.to_h.merge("RUFLET_BACKEND_URL" => url_override)
        Ruflet::Rails::DesktopLauncher.launch_once(root: ::Rails.root, env: env_override)
      end

      rake_tasks do
        namespace :ruflet do
          desc "Build Ruflet native client for this Rails app. Usage: rake ruflet:build[platform]"
          task :build, [:platform] do |_task, args|
            platform = args[:platform].to_s.strip.downcase

            cfg        = Ruflet::Rails.config
            ruflet_url = cfg.backend_url.to_s.strip
            build_args = Ruflet::Rails::InstallSupport.build_args_for_platform(platform, ruflet_url: ruflet_url)

            if build_args.empty?
              warn "Usage: rake ruflet:build[apk|android|ios|aab|desktop|macos|windows|linux]"
              next
            end

            require "ruflet/cli"
            require "yaml"
            require "tempfile"

            exit_code = Dir.chdir(::Rails.root) do
              # Rails build metadata lives in config/initializers/ruflet.rb.
              # Serialize it to the CLI's yaml shape for this build invocation.
              yaml_hash = cfg.to_ruflet_yaml_hash
              use_temp  = yaml_hash.any?

              if use_temp
                Tempfile.create(["ruflet", ".yaml"], ::Rails.root) do |f|
                  f.write(yaml_hash.to_yaml)
                  f.flush
                  ENV["RUFLET_CONFIG"] = f.path
                  Ruflet::CLI.command_build(build_args)
                ensure
                  ENV.delete("RUFLET_CONFIG")
                end
              else
                Ruflet::CLI.command_build(build_args)
              end
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
