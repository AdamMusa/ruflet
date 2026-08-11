# frozen_string_literal: true

require "uri"

module Ruflet
  module Rails
    module DesktopLauncher
      module_function

      def launch_once(root:, argv: ARGV, env: ENV, wait: 1.0)
        return false unless desktop_enabled?(argv: argv, env: env)
        return false unless env["RUFLET_RAILS_DESKTOP_SERVER"].to_s.downcase == "true" || rails_server_command?(argv)
        return false if env["RUFLET_RAILS_DESKTOP"].to_s.downcase == "false"
        return false if launched?

        @launched = true
        url = backend_url(root: root, argv: argv, env: env)
        Thread.new do
          sleep wait.to_f if wait.to_f.positive?
          launch(url, root: root)
        end
        true
      end

      def launch(url, root:)
        require "ruflet/cli"

        Dir.chdir(root.to_s) do
          wait_for_backend(url)
          if Ruflet::CLI.respond_to?(:launch_desktop_client, true)
            Ruflet::CLI.send(:launch_desktop_client, url)
          else
            warn "Ruflet desktop launcher is unavailable in this ruflet version."
            nil
          end
        end
      rescue StandardError => e
        warn "Failed to launch Ruflet desktop client: #{e.class}: #{e.message}"
        nil
      end

      def backend_url(root:, argv: ARGV, env: ENV)
        explicit = env["RUFLET_BACKEND_URL"].to_s.strip
        return explicit unless explicit.empty?

        config_url = ruflet_yaml_backend_url(root)
        cli_port = rails_server_port(argv)
        return replace_url_port(config_url, cli_port) if cli_port
        return config_url if config_url

        "http://localhost:#{env["PORT"].to_s.empty? ? 3000 : env["PORT"]}"
      end

      def desktop_enabled?(argv: ARGV, env: ENV)
        return true if env["RUFLET_RAILS_DESKTOP_SERVER"].to_s.downcase == "true"
        return true if env["RUFLET_RAILS_DESKTOP"].to_s.downcase == "true"
        return true if Array(argv).map(&:to_s).include?("--desktop")

        false
      end

      def rails_server_command?(argv)
        command = Array(argv).find { |value| !value.to_s.start_with?("-") }.to_s
        %w[server s].include?(command)
      end

      def rails_server_port(argv)
        values = Array(argv).map(&:to_s)
        values.each_with_index do |value, index|
          return values[index + 1].to_i if %w[-p --port].include?(value) && values[index + 1].to_i.positive?
          return value.split("=", 2).last.to_i if value.start_with?("--port=") && value.split("=", 2).last.to_i.positive?
        end
        nil
      end

      def ruflet_yaml_backend_url(root)
        path = %w[ruflet.yaml ruflet.yml].map { |name| File.join(root.to_s, name) }.find { |candidate| File.file?(candidate) }
        return nil unless path

        require "yaml"
        config = YAML.safe_load(File.read(path), aliases: true) || {}
        value = config.dig("app", "backend_url") || config["backend_url"] || config["server_url"]
        value.to_s.strip.empty? ? nil : value.to_s.strip
      rescue StandardError
        nil
      end

      def replace_url_port(url, port)
        return "http://localhost:#{port}" if url.to_s.strip.empty?

        uri = URI.parse(url)
        uri.port = port.to_i
        uri.to_s
      rescue URI::InvalidURIError
        "http://localhost:#{port}"
      end

      def wait_for_backend(url)
        return unless Ruflet::CLI.respond_to?(:wait_for_server_boot, true)

        uri = URI.parse(url)
        Ruflet::CLI.send(:wait_for_server_boot, uri.port) if uri.port
      rescue URI::InvalidURIError
        nil
      end

      def launched?
        !!@launched
      end

      def reset!
        @launched = false
      end
    end
  end
end
