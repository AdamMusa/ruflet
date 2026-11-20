# frozen_string_literal: true

require "pathname"

# Just enough of Rails for ruflet_rails' Railtie and a Rails app's
# config/initializers/ruflet.rb to load without the rails gem: Rails.root,
# Rails.env, a Railtie base class that collects rake_tasks blocks, and a rake
# DSL that records the tasks so the real task bodies can be invoked.
#
# The task bodies are the Railtie's own; only rake's command line is stood in
# for here: `name[a,b]` argument parsing, `rake --tasks`, and the error for a
# task that does not exist. Their wording follows rake 13.
module CompatRails
  RAKE_BLOCKS = []
  # "ruflet:build" => [params, description, block]
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
      @description = nil
    end

    def namespace(name)
      @namespaces.push(name.to_s)
      yield
    ensure
      @namespaces.pop
    end

    def desc(description)
      @description = description
    end

    def task(name, params = [], &block)
      key = name.is_a?(Hash) ? name.keys.first : name
      TASKS[(@namespaces + [key.to_s]).join(":")] = [Array(params), @description, block]
      @description = nil
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

  # `rake ARGV`: "ruflet:build[apk]" runs that task's body with
  # platform: "apk"; "--tasks"/"-T" lists the described tasks.
  def invoke_rake(argv)
    return list_tasks if argv == ["--tasks"] || argv == ["-T"]

    argv.each do |invocation|
      name, raw = invocation.match(/\A([^\[]+)(?:\[(.*)\])?\z/).captures
      unless TASKS.key?(name)
        $stderr.write("rake aborted!\n#{undefined_task_message(name)}\n(See full trace by running task with --trace)\n")
        return 1
      end

      params, _description, block = TASKS.fetch(name)
      values = raw.to_s.split(",").map(&:strip)
      block.call(FakeTask.new(name), TaskArguments.new(params.map(&:to_sym).zip(values).to_h))
    end
    0
  end

  # Rake::Application#display_tasks_and_comments: name[args] padded to the
  # widest, then the first sentence of the description.
  def list_tasks
    tasks = TASKS.select { |_name, (_params, description, _block)| description }.sort_by(&:first).map do |name, (params, description, _block)|
      ["#{name}#{params.empty? ? '' : "[#{params.join(',')}]"}", first_sentence(description)]
    end
    width = tasks.map { |name, _| name.length }.max || 10
    tasks.each { |name, comment| $stdout.write(format("rake %-#{width}s  # %s\n", name, comment)) }
    0
  end

  def first_sentence(text)
    text.split(/(?<=\w)(\.|!)[ \t]|(\.$|!)|\n/).first
  end

  # Rake::TaskManager#generate_message_for_undefined_task, including its
  # did_you_mean suggestion. Rake also prints a backtrace line here, which
  # names an install path rather than behavior, so it is left out. In a real
  # app the suggestions are drawn from every task the app defines; here they
  # come from the Railtie's tasks alone.
  def undefined_task_message(name)
    message = "Don't know how to build task '#{name}' (See the list of available tasks with `rake --tasks`)"
    return message unless defined?(::DidYouMean::SpellChecker) && ::DidYouMean.respond_to?(:formatter)

    suggestions = ::DidYouMean::SpellChecker.new(dictionary: TASKS.keys).correct(name)
    message + ::DidYouMean.formatter.message_for(suggestions)
  end
end
