# frozen_string_literal: true

require "rails/generators"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class ScaffoldGenerator < ::Rails::Generators::Base
      argument :model_name, type: :string
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

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

      def clean_legacy_entrypoint_requires
        target = File.join(destination_root, entrypoint_path)
        return unless File.file?(target)

        content = File.read(target)
        [legacy_entrypoint_require, legacy_entrypoint_load].each do |line|
          gsub_file target, "#{line}\n", "" if content.include?("#{line}\n")
        end
      end

      def print_scaffold_status
        say "Ruflet scaffold generated at #{scaffold_view_path}"
        say "The Rails mount loads Ruflet views from #{File.dirname(scaffold_view_path)}."
      end

      private

      def scaffold_view_path
        Ruflet::Rails::InstallSupport.scaffold_view_path(model_name)
      end

      def entrypoint_path
        Ruflet::Rails::InstallSupport.default_entrypoint_path
      end

      def legacy_entrypoint_require
        names = Ruflet::Rails::InstallSupport.scaffold_names(model_name)

        %(require_relative "#{names[:plural]}/#{names[:plural]}_view")
      end

      def legacy_entrypoint_load
        names = Ruflet::Rails::InstallSupport.scaffold_names(model_name)

        %(load File.expand_path("#{names[:plural]}/#{names[:plural]}_view.rb", __dir__))
      end
    end
  end
end
