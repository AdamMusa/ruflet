# frozen_string_literal: true

require "optparse"

require_relative "cli/templates"
require_relative "cli/new_command"
require_relative "cli/run_command"
require_relative "cli/build_command"

module Ruflet
  module CLI
    extend self
    extend NewCommand
    extend RunCommand
    extend BuildCommand

    def run(argv = ARGV)
      command = (argv.shift || "help").downcase

      case command
      when "new", "bootstrap", "init"
        command_new(argv)
      when "run"
        command_run(argv)
      when "build"
        command_build(argv)
      when "help", "-h", "--help"
        print_help
        0
      else
        warn "Unknown command: #{command}"
        print_help
        1
      end
    end

    def print_help
      puts <<~HELP
        Ruflet CLI

        Commands:
          ruflet new <appname>
          ruflet run [scriptname|path] [--web|--mobile|--desktop]
          ruflet build <apk|ios|aab|web|macos|windows|linux>
      HELP
    end

    def bootstrap(path)
      command_new([path || Dir.pwd])
      0
    end
  end
end
