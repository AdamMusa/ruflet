# frozen_string_literal: true

require "rails/generators"
require "active_support/core_ext/string/inflections"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class ScaffoldGenerator < ::Rails::Generators::Base
      argument :model_name, type: :string
      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      desc "Generate a Rails-first Ruflet resource component for an existing model."

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
        say "Ruflet resource component generated at #{scaffold_component_path}"
        say "Mount it in config/routes.rb:"
        say "  mount Ruflet::Rails.web_app(view: #{scaffold_component_class.inspect}), at: \"/#{scaffold_route_segment}\""
      end

      private

      def scaffold_component_class
        "#{model_name.to_s.camelize}Component"
      end

      def scaffold_route_segment
        model_name.to_s.underscore.pluralize
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
