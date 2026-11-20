# frozen_string_literal: true

require "optparse"

require_relative "version"
require_relative "cli/commands"
require_relative "cli/templates"
require_relative "cli/new_command"
require_relative "cli/flutter_sdk"
require_relative "cli/run_command"
require_relative "cli/update_command"
require_relative "cli/build_command"
require_relative "cli/extra_command"

module Ruflet
  module CLI
    extend self
    extend NewCommand
    extend RunCommand
    extend UpdateCommand
    extend BuildCommand
    extend ExtraCommand

    # Runs the command the first argument names (see cli/commands.rb) with
    # the remaining arguments and returns its exit status.
    def run(argv = ARGV)
      command = (argv.shift || "help").downcase
      ensure_first_run_assets(command)

      entry = Commands.lookup(command)
      unless entry
        warn "Unknown command: #{command}"
        print_help
        return 1
      end

      send(entry.handler, argv)
    end

    def print_help
      puts Commands.help_text
    end

    def bootstrap(path)
      command_new([path || Dir.pwd])
      0
    end

    def version_string
      "ruflet #{Ruflet::VERSION}"
    end

    private

    def command_version(_args)
      puts version_string
      0
    end

    def command_help(_args)
      print_help
      0
    end

    def ensure_first_run_assets(command)
      return unless Commands.lookup(command)&.first_run_assets
      return unless respond_to?(:download_ruflet_assets, true)

      send(:download_ruflet_assets)
    rescue StandardError
      nil
    end
  end
end
