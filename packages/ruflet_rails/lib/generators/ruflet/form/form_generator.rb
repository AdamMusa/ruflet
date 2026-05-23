# frozen_string_literal: true

require "rails/generators"
require "active_support/core_ext/string/inflections"
require "ruflet/rails/install_support"

module Ruflet
  module Generators
    class FormGenerator < ::Rails::Generators::Base
      argument :model_name, type: :string
      argument :attributes, type: :array, default: [], banner: "field:type field:type"
      class_option :target, type: :string, default: "frontend", desc: "App views folder for the generated form: frontend, mobile, web, desktop, or a custom folder"

      desc "Generate only a Ruflet form for an existing Rails model."

      def create_ruflet_form
        target = File.join(destination_root, form_view_path)

        create_file(
          target,
          Ruflet::Rails::InstallSupport.form_view_template(
            model_name: model_name,
            attributes: form_attributes
          )
        )
      end

      def print_form_status
        names = Ruflet::Rails::InstallSupport.scaffold_names(model_name)
        say "Ruflet form generated at #{form_view_path}"
        say "Require it and call #{names[:class_name]}Form.render(page, record: #{names[:class_name]}.new)."
      end

      private

      def form_view_path
        Ruflet::Rails::InstallSupport.form_view_path(model_name, target: options[:target])
      end

      def form_attributes
        return attributes unless attributes.empty?

        model_class = model_name.to_s.camelize.safe_constantize
        inferred = Ruflet::Rails::InstallSupport.attributes_from_model(model_class)
        inferred.empty? ? attributes : inferred
      end
    end
  end
end
