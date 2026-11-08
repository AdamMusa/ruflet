# frozen_string_literal: true

require "pathname"

# Just enough of Rails for ruflet_rails' Railtie and a Rails app's
# config/initializers/ruflet.rb to load without the rails gem: Rails.root,
# Rails.env, a Railtie base class that collects rake_tasks blocks, and a rake
# DSL that records the tasks so the real task bodies can be invoked.
module CompatRails
  RAKE_BLOCKS = []
  TASKS = {}

  class Environment < String
    def method_missing(name, *args)
      return self == name.to_s.delete_suffix("?") if name.to_s.end_with?("?") && args.empty?

      super
    end

    def respond_to_missing?(name, include_private = false)
      name.to_s.end_with?("?") || super
    end
  end

  class RakeDSL
    def initialize
      @namespaces = []
    end

    def namespace(name)
      @namespaces.push(name.to_s)
      yield
    ensure
      @namespaces.pop
    end

    def desc(_description); end

    def task(name, params = [], &block)
      key = name.is_a?(Hash) ? name.keys.first : name
      TASKS[(@namespaces + [key.to_s]).join(":")] = [Array(params), block]
    end
  end

  class TaskArguments
    def initialize(values)
      @values = values
    end

    def [](name) = @values[name.to_sym]
    def to_h = @values.dup
  end

  FakeTask = Struct.new(:name)

  module_function

  def boot(root)
    root_path = Pathname.new(root)
    rails = Module.new
    rails.define_singleton_method(:root) { root_path }
    rails.define_singleton_method(:env) { Environment.new("development") }
    railtie = Class.new do
      def self.initializer(*_args, **_options, &_block); end

      def self.rake_tasks(&block)
        CompatRails::RAKE_BLOCKS << block
      end
    end
    rails.const_set(:Railtie, railtie)
    Object.const_set(:Rails, rails)

    require "ruflet_rails"
    RAKE_BLOCKS.each { |block| RakeDSL.new.instance_exec(&block) }
    initializer = File.join(root, "config", "initializers", "ruflet.rb")
    load initializer if File.file?(initializer)
  end

  # "ruflet:build[apk]" -> runs that task's body with platform: "apk".
  def invoke_rake(invocation)
    name, raw = invocation.match(/\A([^\[]+)(?:\[(.*)\])?\z/).captures
    params, block = TASKS.fetch(name)
    values = raw.to_s.split(",")
    block.call(FakeTask.new(name), TaskArguments.new(params.map(&:to_sym).zip(values).to_h))
    0
  end
end
