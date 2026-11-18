# frozen_string_literal: true

require "fileutils"

# Just enough of railties' Rails::Generators::Base, and the Thor it is built
# on, for ruflet_rails' `rails generate ruflet:install` to run without the
# rails gem. It is on the load path only for generator goldens
# (lib/cli_child.rb, mode "generator"), so `require "rails/generators"` in the
# generator resolves here.
#
# Each piece follows railties 8.1 / Thor 1.x line for line where the
# generator's output depends on it: option parsing (Thor::Options), the steps
# run in definition order (Thor::Group), create_file, insert_into_file and
# route (Thor::Actions, Rails::Generators::Actions), and the status lines a
# non-tty shell prints (Thor::Shell::Basic). Options the generator does not
# declare are ignored, as in Rails. When railties is installed,
# compat_goldens_test.rb runs every generator golden against the real
# railties as well and requires identical output.
class Thor
  class Error < StandardError; end
end

module Rails
  module Generators
    class Base
      class Options < Hash
        def [](key) = super(key.to_s)
        def key?(key) = super(key.to_s)
        def fetch(key, *args, &block) = super(key.to_s, *args, &block)
      end

      class << self
        def class_option(name, type:, default: nil, desc: nil) # rubocop:disable Lint/UnusedMethodArgument
          own_class_options[name.to_s] = { type: type, default: default }
        end

        def own_class_options = (@class_options ||= {})

        def desc(_description = nil); end

        def source_root(*); end

        # Thor::Group: every public instance method is a step, run in the order
        # it was defined.
        def method_added(name)
          super
          steps << name if public_method_defined?(name)
        end

        def steps = (@steps ||= [])

        def start(given_args = ARGV, config = {})
          generator = new(parse_options(given_args.dup), config.fetch(:destination_root, Dir.pwd))
          steps.each { |step| generator.public_send(step) }
          nil
        rescue Thor::Error => e
          # Thor::Base.start: the shell reports the error and, since Rails
          # generators do not exit on failure, the command returns.
          $stderr.puts(e.message)
          nil
        end

        # Thor::Options#parse for --name, --name=value, --no-name/--skip-name
        # (booleans), and a string option given without a value, which Thor
        # sets to the option's human name.
        def parse_options(args)
          options = Options.new
          own_class_options.each { |name, option| options[name] = option[:default] unless option[:default].nil? }
          until args.empty?
            arg = args.shift
            next unless arg.start_with?("--")

            switch, value = arg.delete_prefix("--").split("=", 2)
            negated = switch.match(/\A(?:no|skip)-(.+)\z/)
            name = (negated ? negated[1] : switch).tr("-", "_")
            option = own_class_options[name]
            args.unshift(value) if value && option&.dig(:type) == :boolean
            if option.nil?
              next
            elsif option[:type] == :boolean
              # Thor::Options#parse_boolean: an explicit true/false value is
              # consumed; anything else is left alone.
              options[name] = if %w[true TRUE t T].include?(args.first)
                                args.shift
                                true
                              elsif %w[false FALSE f F].include?(args.first)
                                args.shift
                                false
                              else
                                !negated
                              end
            elsif value
              options[name] = value
            elsif args.empty? || args.first.start_with?("-")
              options[name] = name.tr("_", " ")
            else
              options[name] = args.shift
            end
          end
          options
        end
      end

      attr_reader :options, :destination_root

      def initialize(options, destination_root)
        @options = options
        @destination_root = File.expand_path(destination_root)
      end

      private

      # --- Thor::Shell::Basic (not a tty) ---------------------------------------

      def say(message = "", _color = nil, force_new_line = (message.to_s !~ /( |\t)\Z/))
        buffer = message.to_s.dup
        buffer << "\n" if force_new_line && !message.to_s.end_with?("\n")
        $stdout.print(buffer)
        $stdout.flush
      end

      def say_status(status, message, log_status = true)
        return if log_status == false

        spaces = "  "
        status = status.to_s.rjust(12)
        margin = " " * status.length + spaces
        $stdout.print("#{status}#{spaces}#{message.to_s.chomp.gsub(/(?<!\A)^/, margin)}\n")
        $stdout.flush
      end

      # --- Thor::Actions --------------------------------------------------------

      def relative_to_original_destination_root(path)
        root = @destination_root
        return path unless path.start_with?(root) && [File::SEPARATOR, nil, ""].include?(path[root.size..root.size])

        path[(root.size + 1)..] || ""
      end

      def create_file(destination, data = nil, _config = {})
        path = File.expand_path(destination, @destination_root)
        raise NotImplementedError, "compat generator stub: #{path} already exists" if File.exist?(path)

        say_status(:create, relative_to_original_destination_root(path))
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "wb") { |file| file.write(data.to_s) }
        path
      end

      # Thor::Actions::InjectIntoFile#invoke!, :after only.
      def insert_into_file(destination, data, config = {})
        path = File.expand_path(destination, @destination_root)
        verbose = config.fetch(:verbose, true)
        flag = config.fetch(:after)
        flag = Regexp.escape(flag) unless flag.is_a?(Regexp)
        raise Thor::Error, "The file #{path} does not appear to exist" unless File.exist?(path)

        relative = relative_to_original_destination_root(path)
        content = File.read(path)
        success = nil
        if config[:force] || !content.include?(data)
          success = content.gsub!(/#{flag}/, '\0' + data)
          File.open(path, "wb") { |file| file.write(content) }
        end
        if success
          say_status(:insert, relative, verbose)
        elsif content.include?(data)
          say_status(:unchanged, relative, :blue)
        else
          say_status("File unchanged! Either the supplied flag value not found or the content has already been inserted!",
                     relative, :red)
        end
      end
      alias inject_into_file insert_into_file

      # --- Rails::Generators::Actions -----------------------------------------

      def route(routing_code)
        say_status(:route, routing_code, :green)
        pattern = /^([ ]*).+\.routes\.draw do[ ]*\n/
        routes = File.join(@destination_root, "config", "routes.rb")
        if File.exist?(routes) && (match = File.read(routes).match(pattern))
          base_indent, *, existing_block_indent = match.captures.compact.map(&:length)
          existing_line_pattern = /^[ ]{,#{existing_block_indent}}\S.+\n?/
          routing_code = optimize_indentation(routing_code, base_indent + 2).gsub(existing_line_pattern, "")
          pattern = /#{Regexp.escape match.to_s}/
        end
        insert_into_file("config/routes.rb", routing_code, after: pattern, verbose: false, force: false)
      end

      # optimize_indentation with ActiveSupport's String#strip_heredoc and
      # String#indent.
      def optimize_indentation(value, amount = 0)
        return "#{value}\n" unless value.is_a?(String)

        stripped = value.gsub(/^#{value.scan(/^[ \t]*(?=\S)/).min}/, "")
        indent_string = stripped[/^[ \t]/] || " "
        "#{stripped.gsub(/^(?!$)/, indent_string * amount).chomp}\n"
      end
    end
  end
end
