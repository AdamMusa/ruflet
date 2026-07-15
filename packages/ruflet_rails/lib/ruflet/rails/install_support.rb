# frozen_string_literal: true

require "rbconfig"

module Ruflet
  module Rails
    module InstallSupport
      module_function

      def default_app_template(app_title:)
        <<~RUBY
          # frozen_string_literal: true

          # The home screen for this Ruflet app. You own this file; nothing is
          # auto-discovered. It is mounted explicitly in config/routes.rb:
          #   match "/ws", to: Ruflet::Rails.app(Rails.root.join("app/views/ruflet/main.rb")), via: :all
          Ruflet.run do |page|
            page.title = #{app_title.inspect}
            page.add(
              safe_area(
                container(
                  expand: true,
                  padding: 24,
                  content: column(
                    spacing: 12,
                    controls: [
                      text(#{app_title.inspect}, size: 24, weight: "bold"),
                      text("Edit app/views/ruflet/main.rb to build your app.")
                    ]
                  )
                ),
                expand: true
              )
            )
          end
        RUBY
      end

      def default_ruflet_yaml(app_name:)
        <<~YAML
          app:
            name: #{app_name}
            backend_url: #{default_backend_url}

          services: []

          assets:
            splash_screen: assets/splash.png
            icon_launcher: assets/icon.png
        YAML
      end

      def default_initializer(app_name:)
        <<~RUBY
          # frozen_string_literal: true

          Ruflet::Rails.configure do |config|
            config.app_name = #{app_name.inspect}
            config.backend_url = ENV.fetch("RUFLET_BACKEND_URL", #{default_backend_url.inspect})

            config.services = []

            # Build assets. Replace these with your app artwork when ready.
            config.splash_screen = Rails.root.join("app/assets/images/splash.png")
            config.icon_launcher = Rails.root.join("app/assets/images/icon.png")
          end
        RUBY
      end

      def ruby_desktop_flag_bootstrap
        <<~RUBY
          # ruflet_rails desktop flag
          ruflet_rails_desktop = ARGV.include?("--desktop")
          ruflet_rails_command = ARGV.find { |value| !value.to_s.start_with?("-") }
          if ruflet_rails_desktop && %w[server s].include?(ruflet_rails_command.to_s)
            ENV["RUFLET_RAILS_DESKTOP"] = "true"
            ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"
          end
          ARGV.delete("--desktop")

        RUBY
      end

      def ruby_dev_desktop_flag_bootstrap
        <<~RUBY
          # ruflet_rails desktop flag
          if ARGV.delete("--desktop")
            ENV["RUFLET_RAILS_DESKTOP"] = "true"
            ENV["RUFLET_RAILS_DESKTOP_SERVER"] = "true"
          end

        RUBY
      end

      def shell_desktop_flag_bootstrap
        <<~SH
          # ruflet_rails desktop flag
          if [ "$1" = "--desktop" ]; then
            export RUFLET_RAILS_DESKTOP=true
            export RUFLET_RAILS_DESKTOP_SERVER=true
            shift
          fi

        SH
      end

      def default_backend_url
        "http://localhost:3000"
      end

      def host_desktop_platform
        host_os = RbConfig::CONFIG["host_os"]
        return "macos" if host_os.match?(/darwin/i)
        return "linux" if host_os.match?(/linux/i)
        return "windows" if host_os.match?(/mswin|mingw|cygwin/i)

        nil
      end

      def normalize_build_platform(platform)
        value = platform.to_s.strip.downcase
        return host_desktop_platform if value == "desktop"

        value
      end

      # ruflet_rails builds only native clients. The web client is installed
      # prebuilt (rake ruflet:web), never compiled, so "web" is not a build
      # target here.
      def build_args_for_platform(platform, ruflet_url: nil)
        normalized = normalize_build_platform(platform)
        return [] if normalized.to_s.empty?
        return [] if normalized == "web"

        [normalized]
      end

      def default_entrypoint_path
        File.join("app", "views", "ruflet", "main.rb")
      end

      def route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ws", helper: "app")
        %(match "#{mount_path}", to: Ruflet::Rails.#{helper}(Rails.root.join("#{entrypoint}")), via: :all)
      end

      def web_route_snippet(entrypoint: default_entrypoint_path, mount_path: "/ruflet")
        %(mount Ruflet::Rails.web_app(app_file: Rails.root.join("#{entrypoint}")), at: "#{mount_path}")
      end

      def install_next_steps(target:, entrypoint:, client:, mount_path: "/ws")
        lines = [
          "Ruflet Rails installed.",
          "Generated entrypoint: #{entrypoint}",
          "Added WebSocket route #{mount_path} to config/routes.rb",
          "Next steps:",
          "  1. Start Rails: bin/rails server",
          "  2. Connect your Ruflet app to ws://localhost:3000#{mount_path}"
        ]

        if %w[desktop all].include?(client.to_s)
          lines += [
            "Desktop clients are server-driven and connect to this Rails app.",
            "Plain bin/dev, bin/rails server, and bin/rails s do not launch desktop.",
            "To launch desktop for a dev server run: bin/rails s --desktop or bin/dev --desktop",
            "To download the prebuilt desktop client: bin/rails ruflet:update[desktop]",
            "To build the host desktop client: bin/rails ruflet:build[desktop]"
          ]
        end

        if %w[web all].include?(client.to_s)
          lines += [
            "Web client installed into frontend/.",
            "Open the mounted Ruflet web app at http://localhost:3000/ruflet"
          ]
        end

        lines
      end
    end
  end
end
