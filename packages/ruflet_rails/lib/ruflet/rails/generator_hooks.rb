# frozen_string_literal: true

module Ruflet
  module Rails
    module GeneratorHooks
      module_function

      def install!
        require "active_support/core_ext/string/filters"
        require "rails/generators/rails/scaffold/scaffold_generator"
        require "generators/ruflet/scaffold/scaffold_generator"

        generator = ::Rails::Generators::ScaffoldGenerator
        return if generator.class_options.key?(:ruflet)

        generator.hook_for(
          :ruflet,
          type: :boolean,
          default: true,
          desc: "Generate a Ruflet resource component"
        )
      end
    end
  end
end
