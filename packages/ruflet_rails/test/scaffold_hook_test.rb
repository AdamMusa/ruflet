# frozen_string_literal: true

require_relative "test_helper"

class RufletRailsScaffoldHookTest < Minitest::Test
  def test_rails_scaffold_ruflet_option_delegates_to_same_ruflet_scaffold_generator
    fake_generator = Class.new do
      class << self
        attr_reader :options

        def class_option(name, config)
          @options ||= {}
          @options[name] = config
        end
      end

      attr_reader :invoked

      def options
        { ruflet: true }
      end

      def name
        "Post"
      end

      def attributes
        [
          Struct.new(:name, :type).new("title", "string"),
          Struct.new(:name, :type).new("body", "text")
        ]
      end

      def invoke(generator_name, args, config = {})
        @invoked = [generator_name, args, config]
      end
    end

    assert Ruflet::Rails::ScaffoldHook.install!(scaffold_generator: fake_generator)
    instance = fake_generator.new
    instance.create_ruflet_scaffold_view

    assert_equal false, fake_generator.options[:ruflet][:default]
    refute fake_generator.options.key?(:ruflet_target)
    assert_equal ["ruflet:scaffold", ["Post", "title:string", "body:text"], {}], instance.invoked
  end

  def test_rails_scaffold_ruflet_option_uses_ruflet_target_by_default
    fake_generator = Class.new do
      class << self
        def class_option(_name, _config); end
      end

      attr_reader :invoked

      def options
        { ruflet: true }
      end

      def name
        "Post"
      end

      def attributes
        [Struct.new(:name, :type).new("title", "string")]
      end

      def invoke(generator_name, args, config = {})
        @invoked = [generator_name, args, config]
      end
    end

    assert Ruflet::Rails::ScaffoldHook.install!(scaffold_generator: fake_generator)
    instance = fake_generator.new
    instance.create_ruflet_scaffold_view

    assert_equal ["ruflet:scaffold", ["Post", "title:string"], {}], instance.invoked
  end
end
