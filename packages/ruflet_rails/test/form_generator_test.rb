# frozen_string_literal: true

require_relative "test_helper"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "rails/generators"
require "generators/ruflet/form/form_generator"

class RufletFormGeneratorTest < Minitest::Test
  RailsGenerators = ::Rails::Generators

  def test_rails_generator_lookup_generates_form_component
    Dir.mktmpdir do |dir|
      capture_io do
        RailsGenerators.invoke(
          "ruflet:form",
          ["Post", "title:string", "body:text"],
          destination_root: dir
        )
      end

      form_path = File.join(dir, "app/views/ruflet/components/posts/post_form.rb")
      source = File.read(form_path)

      assert_includes source, "class PostForm < ApplicationComponent"
      assert_includes source, '{ name: "title", type: "string" }'
      assert_includes source, '{ name: "body", type: "text" }'
    end
  end

  def test_generates_reusable_form_component_for_model_attributes
    Dir.mktmpdir do |dir|
      generator = Ruflet::Generators::FormGenerator.new(
        ["Post", "title:string", "published:boolean"],
        {},
        destination_root: dir
      )

      capture_io { generator.invoke_all }

      form_path = File.join(dir, "app/views/ruflet/components/posts/post_form.rb")
      component_path = File.join(dir, "app/views/ruflet/components/application_component.rb")

      assert File.file?(form_path)
      assert File.file?(component_path)

      source = File.read(form_path)
      assert_includes source, "class PostForm < ApplicationComponent"
      assert_includes source, "def render(record:, title: nil, on_save: nil, on_cancel: nil)"
      assert_includes source, "def form_fields"
      assert_includes source, '{ name: "title", type: "string" }'
      assert_includes source, '{ name: "published", type: "boolean" }'
      refute_includes source, "data_table("
      refute_includes source, "record.destroy"
    end
  end

  def test_infers_attributes_from_existing_model_when_none_are_passed
    column = Struct.new(:name, :type)
    model = Class.new do
      local_column = column
      define_singleton_method(:columns) do
        [
          local_column.new("id", :integer),
          local_column.new("title", :string),
          local_column.new("published_on", :date),
          local_column.new("created_at", :datetime),
          local_column.new("updated_at", :datetime)
        ]
      end
    end
    Object.const_set(:GeneratedPost, model)

    Dir.mktmpdir do |dir|
      generator = Ruflet::Generators::FormGenerator.new(
        ["GeneratedPost"],
        {},
        destination_root: dir
      )

      capture_io { generator.invoke_all }

      source = File.read(File.join(dir, "app/views/ruflet/components/generated_posts/generated_post_form.rb"))
      assert_includes source, '{ name: "title", type: "string" }'
      assert_includes source, '{ name: "published_on", type: "date" }'
      refute_includes source, '{ name: "id", type: "integer" }'
      refute_includes source, '{ name: "created_at", type: "datetime" }'
      refute_includes source, '{ name: "updated_at", type: "datetime" }'
    end
  ensure
    Object.send(:remove_const, :GeneratedPost) if Object.const_defined?(:GeneratedPost) && Object.const_get(:GeneratedPost) == model
  end
end
