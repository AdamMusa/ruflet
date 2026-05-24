# frozen_string_literal: true

require "rails/generators"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      class_option :frontend, type: :boolean, default: false, desc: "Install the Rails-hosted Ruflet web client"
      class_option :client, type: :string, default: nil, desc: "Download prebuilt client from GitHub releases: web, desktop, all, or none"

      desc "Install Ruflet into a Rails app."

      def create_app_entrypoint
        target = File.join(destination_root, entrypoint_path)
        return if File.exist?(target)

        create_file target, Ruflet::Rails::InstallSupport.default_app_template(app_title: app_name)
      end

      def create_application_component
        target = File.join(destination_root, Ruflet::Rails::InstallSupport.application_component_path)
        return if File.exist?(target)

        create_file target, Ruflet::Rails::InstallSupport.application_component_template
      end

      def create_ruflet_yaml
        target = File.join(destination_root, "ruflet.yaml")
        return if File.exist?(target)

        create_file target, Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: app_name)
      end

      def add_routes
        target = File.join(destination_root, "config/routes.rb")
        return unless File.file?(target)

        route = Ruflet::Rails::InstallSupport.route_snippet(entrypoint: entrypoint_path)
        return if File.read(target).include?(route)

        insert_into_file target, "  #{route}\n", after: /Rails\.application\.routes\.draw do\s*\n/
      end

      def download_prebuilt_client
        client = requested_client
        @web_client_published = false
        return if client == "none"

        if %w[web all].include?(client)
          @web_client_published = Ruflet::Rails::InstallSupport.publish_web_build(destination_root)
          if @web_client_published
            say "Ruflet web build copied from build/web to public/#{Ruflet::Rails::InstallSupport.default_web_public_path}"
            return if client == "web"
          end
        end

        require "ruflet/cli"
        exit_code = Dir.chdir(destination_root) do
          Ruflet::CLI.command_update([client])
        end
        raise Thor::Error, "ruflet client download failed" unless exit_code.to_i.zero?

        return unless %w[web all].include?(client)

        published = Ruflet::Rails::InstallSupport.publish_prebuilt_web_client(destination_root)
        @web_client_published = published
        if published
          say "Ruflet web client published at /#{Ruflet::Rails::InstallSupport.default_web_public_path}/"
        else
          say_status(:warn, "Ruflet web client downloaded, but no prebuilt web index.html was found to publish", :yellow)
        end
      end

      def print_install_status
        Ruflet::Rails::InstallSupport.install_next_steps(
          target: install_target,
          entrypoint: entrypoint_path,
          client: requested_client,
          web_published: !!@web_client_published
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

        return "web" if options[:frontend]

        "none"
      end

      def install_target
        "ruflet"
      end
    end
  end
end
