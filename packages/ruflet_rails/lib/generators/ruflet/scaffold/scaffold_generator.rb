# frozen_string_literal: true

require "rails/generators"
require "active_support/core_ext/string/inflections"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class ScaffoldGenerator < ::Rails::Generators::Base
      argument :model_name, type: :string
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      desc "Generate a Rails-first Ruflet resource view for an existing model."

      def create_ruflet_resource_view
        create_file(
          File.join(destination_root, scaffold_view_path),
          Ruflet::Rails::InstallSupport.scaffold_view_template(
            model_name: model_name,
            attributes: scaffold_attributes
          )
        )
      end

      def create_ruflet_resource_component
        create_file(
          File.join(destination_root, scaffold_component_path),
          Ruflet::Rails::InstallSupport.scaffold_component_template(
            model_name: model_name,
            attributes: scaffold_attributes
          )
        )
      end

      def print_scaffold_status
        say "Ruflet scaffold generated at #{scaffold_view_path}"
        say "Ruflet UI component generated at #{scaffold_component_path}"
        say "The generated view owns the resource logic; the generated component owns the UI."
      end

      private

      def scaffold_view_path
        Ruflet::Rails::InstallSupport.scaffold_view_path(model_name)
      end

      def scaffold_component_path
        Ruflet::Rails::InstallSupport.scaffold_component_path(model_name)
      end

      def scaffold_attributes
        return attributes unless attributes.empty?

        model_class = model_name.to_s.camelize.safe_constantize
        inferred = Ruflet::Rails::InstallSupport.attributes_from_model(model_class)
        inferred.empty? ? attributes : inferred
      end
    end
  end
end
