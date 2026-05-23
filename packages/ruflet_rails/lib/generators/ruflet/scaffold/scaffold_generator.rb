# frozen_string_literal: true

require "rails/generators"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class ScaffoldGenerator < ::Rails::Generators::Base
      argument :model_name, type: :string
      argument :attributes, type: :array, default: [], banner: "field:type field:type"
      class_option :target, type: :string, default: "frontend", desc: "App folder for the generated view: frontend, mobile, web, desktop, or a custom folder"

      desc "Generate a Ruflet UI scaffold for a Rails model."

      def create_ruflet_scaffold_view
        target = File.join(destination_root, scaffold_view_path)

        create_file(
          target,
          Ruflet::Rails::InstallSupport.scaffold_view_template(
            model_name: model_name,
            attributes: attributes
          )
        )
      end

      def print_scaffold_status
        say "Ruflet scaffold generated at #{scaffold_view_path}"
        say "The Ruflet entrypoint auto-loads *_view.rb files and routes to this view."
      end

      private

      def scaffold_view_path
        Ruflet::Rails::InstallSupport.scaffold_view_path(model_name, target: options[:target])
      end
    end
  end
end
