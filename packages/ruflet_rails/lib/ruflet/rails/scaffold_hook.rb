# frozen_string_literal: true

module Ruflet
  module Rails
    module ScaffoldHook
      module_function

      def install!(scaffold_generator: nil)
        generator = scaffold_generator || rails_scaffold_generator
        return false unless generator
        return true if generator.instance_methods.include?(:create_ruflet_scaffold_view)

        generator.class_option(
          :ruflet,
          type: :boolean,
          default: false,
          desc: "Generate a server-driven Ruflet view for this scaffold"
        )
        generator.class_option(
          :ruflet_target,
          type: :string,
          default: "frontend",
          desc: "App folder for the generated Ruflet view"
        )

        generator.class_eval do
          def create_ruflet_scaffold_view
            return unless options[:ruflet]

            ruflet_attributes = attributes.map do |attribute|
              type = attribute.respond_to?(:type) ? attribute.type : "string"
              "#{attribute.name}:#{type}"
            end

            invoke "ruflet:scaffold", [name, *ruflet_attributes], target: options[:ruflet_target]
          end
        end

        true
      end

      def rails_scaffold_generator
        return ::Rails::Generators::ScaffoldGenerator if defined?(::Rails::Generators::ScaffoldGenerator)

        require "rails/generators/rails/scaffold/scaffold_generator"
        ::Rails::Generators::ScaffoldGenerator if defined?(::Rails::Generators::ScaffoldGenerator)
      rescue LoadError, NameError
        nil
      end
    end
  end
end
