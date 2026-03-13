# frozen_string_literal: true

require "rails/generators"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      desc "Install Ruflet into a Rails app."

      def create_mobile_entrypoint
        target = File.join(destination_root, "app/mobile/main.rb")
        return if File.exist?(target)

        FileUtils.mkdir_p(File.dirname(target))
        File.write(
          target,
          Ruflet::Rails::InstallSupport.default_mobile_app_template(app_title: app_name)
        )
      end

      def create_ruflet_yaml
        target = File.join(destination_root, "ruflet.yaml")
        return if File.exist?(target)

        File.write(
          target,
          Ruflet::Rails::InstallSupport.default_ruflet_yaml(app_name: app_name)
        )
      end

      def copy_client_template
        copied = Ruflet::Rails::InstallSupport.copy_ruflet_client_template(destination_root)
        say_status(:warn, "ruflet_client template not found; add it manually before building", :yellow) unless copied
      end

      def configure_client_template
        Ruflet::Rails::InstallSupport.configure_ruflet_client(destination_root)
      end

      def add_routes
        target = File.join(destination_root, "config/routes.rb")
        return unless File.file?(target)

        route = Ruflet::Rails::InstallSupport.route_snippet
        return if File.read(target).include?(route)

        insert_into_file target, "  #{route}\n", after: /Rails\.application\.routes\.draw do\s*\n/
      end

      def print_install_status
        say "ruflet.yaml generated"
      end

      private

      def app_name
        File.basename(destination_root).gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
