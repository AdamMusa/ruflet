# frozen_string_literal: true

require_relative "test_helper"

local_lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(local_lib) unless $LOAD_PATH.include?(local_lib)

require "generators/ruflet/form/form_generator"

class RufletFormGeneratorTest < Minitest::Test
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
end
