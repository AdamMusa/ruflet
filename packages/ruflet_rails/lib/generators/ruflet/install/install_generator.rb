# frozen_string_literal: true

require "rails/generators"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      class_option :web, type: :boolean, default: false, desc: "Install the prebuilt Ruflet web client"
      class_option :desktop, type: :boolean, default: false, desc: "Download the server-driven desktop Ruflet client"
      class_option :client, type: :string, default: nil, desc: "Install prebuilt clients: web, desktop, all, or none"

      desc "Install Ruflet into a Rails app."

      def create_app_entrypoint
        target = File.join(destination_root, entrypoint_path)
        return if File.exist?(target)

        create_file target, Ruflet::Rails::InstallSupport.default_app_template(app_title: app_name)
      end

      def create_ruflet_yaml
        target = File.join(destination_root, "ruflet.yaml")
        return if File.exist?(target)

        create_file target, Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: app_name)
      end

      # Mount the native WebSocket endpoint explicitly in config/routes.rb.
      # Nothing is auto-mounted — the dev owns the route, like any other.
      def mount_websocket
        routes = File.join(destination_root, "config", "routes.rb")
        return unless File.file?(routes)
        return if File.read(routes).include?("Ruflet::Rails.app(")

        route Ruflet::Rails::InstallSupport.route_snippet(entrypoint: entrypoint_path)
      end

      def mount_web_app
        return unless web_requested?

        routes = File.join(destination_root, "config", "routes.rb")
        return unless File.file?(routes)
        return if File.read(routes).include?("Ruflet::Rails.web_app(")

        route Ruflet::Rails::InstallSupport.web_route_snippet(entrypoint: entrypoint_path)
      end

      def add_desktop_flag_to_binstubs
        return unless desktop_requested?

        install_desktop_flag_bootstrap("bin/rails")
        install_desktop_flag_bootstrap("bin/dev")
      end

      def download_prebuilt_client
        client = requested_client
        return if client == "none"

        install_web_client if %w[web all].include?(client)
        install_desktop_client if %w[desktop all].include?(client)
      rescue StandardError => e
        @client_download_failed = true
        say_status(:warn, "Ruflet client download failed: #{e.class}: #{e.message}", :yellow)
      end

      def print_install_status
        Ruflet::Rails::InstallSupport.install_next_steps(
          target: install_target,
          entrypoint: entrypoint_path,
          client: requested_client
        ).each { |line| say line }
      end

      private

      def app_name
        File.basename(destination_root).gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end

      def entrypoint_path
        Ruflet::Rails::InstallSupport.default_entrypoint_path
      end

      def requested_client
        explicit = options[:client].to_s.strip.downcase
        unless explicit.empty?
          raise Thor::Error, "--client must be web, desktop, all, or none" unless %w[web desktop all none].include?(explicit)

          return explicit
        end

        return "all" if options[:web] && options[:desktop]
        return "web" if options[:web]
        return "desktop" if options[:desktop]

        "none"
      end

      def desktop_requested?
        %w[desktop all].include?(requested_client)
      end

      def web_requested?
        %w[web all].include?(requested_client)
      end

      def install_target
        "ruflet"
      end

      def install_web_client
        return if Ruflet::Rails::WebInstaller.install!(root: destination_root)

        client_download_failed("web")
      end

      def install_desktop_client
        require "ruflet/cli"
        exit_code = Dir.chdir(destination_root) { Ruflet::CLI.command_update(["desktop"]) }
        client_download_failed("desktop") unless exit_code.to_i.zero?
      end

      def client_download_failed(client)
        @client_download_failed = true
        say_status(:warn, "Ruflet #{client} client download failed; install files were still generated", :yellow)
      end

      def install_desktop_flag_bootstrap(relative_path)
        target = File.join(destination_root, relative_path)
        return unless File.file?(target)

        source = File.read(target)
        return if source.include?("ruflet_rails desktop flag")

        bootstrap =
          if source.start_with?("#!/usr/bin/env ruby") || source.start_with?("#!/usr/bin/ruby")
            if File.basename(relative_path) == "dev"
              Ruflet::Rails::InstallSupport.ruby_dev_desktop_flag_bootstrap
            else
              Ruflet::Rails::InstallSupport.ruby_desktop_flag_bootstrap
            end
          elsif source.start_with?("#!/usr/bin/env sh") || source.start_with?("#!/bin/sh")
            Ruflet::Rails::InstallSupport.shell_desktop_flag_bootstrap
          end
        return unless bootstrap

        insert_into_file target, "#{bootstrap}\n", after: /\A#!.*\n/
      end
    end
  end
end
