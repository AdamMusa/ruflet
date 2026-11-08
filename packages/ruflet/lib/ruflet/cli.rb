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
    #
    # -h/--help prints the command's help instead (exit 0), and a flag the
    # command does not read prints its usage on stderr (exit 64). Both are
    # decided before anything is fetched or written.
    def run(argv = ARGV)
      command = (argv.shift || "help").downcase
      entry = Commands.lookup(command)
      if entry
        return print_command_help(entry) if entry.help_requested?(argv)

        begin
          entry.check_flags!(argv)
        rescue OptionParser::ParseError => e
          return report_usage_error(entry, e.message)
        end
      end
      ensure_first_run_assets(command)

      unless entry
        warn "Unknown command: #{command}"
        print_help
        return 1
      end

      begin
        send(entry.handler, argv)
      rescue Commands::HelpRequested
        print_command_help(entry)
      rescue OptionParser::ParseError, Commands::UsageError => e
        report_usage_error(entry, e.message)
      end
    end

    def print_help
      puts Commands.help_text
    end

    # `ruflet help <command>` and `ruflet <command> --help`.
    def print_command_help(entry)
      puts entry.help_text
      0
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

    # `ruflet help` lists the commands; `ruflet help <command>` shows one.
    # A word that is not a command still lists them all.
    def command_help(args)
      word = args.first.to_s.downcase
      entry = Commands.lookup(word)
      return print_command_help(entry) if entry && entry.name != "help"
      raise OptionParser::InvalidOption, args.first if entry.nil? && Commands.flag?(word)

      print_help
      0
    end

    def report_usage_error(entry, message)
      warn "ruflet #{entry.name}: #{message}"
      warn ""
      warn entry.help_text
      Commands::EX_USAGE
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
