# frozen_string_literal: true

require "optparse"

require_relative "cli/templates"
require_relative "cli/new_command"
require_relative "cli/run_command"
require_relative "cli/build_command"
require_relative "cli/extra_command"

module Ruflet
  module CLI
    extend self
    extend NewCommand
    extend RunCommand
    extend BuildCommand
    extend ExtraCommand

    def run(argv = ARGV)
      command = (argv.shift || "help").downcase

      case command
      when "create"
        command_create(argv)
      when "new", "bootstrap", "init"
        command_new(argv)
      when "run"
        command_run(argv)
      when "debug"
        command_debug(argv)
      when "build"
        command_build(argv)
      when "devices"
        command_devices(argv)
      when "emulators"
        command_emulators(argv)
      when "doctor"
        command_doctor(argv)
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
          ruflet create <appname>
          ruflet new <appname>
          ruflet run [scriptname|path] [--web|--mobile|--desktop]
          ruflet debug [scriptname|path]
          ruflet build <apk|ios|aab|web|macos|windows|linux>
          ruflet devices
          ruflet emulators
          ruflet doctor
      HELP
    end

    def bootstrap(path)
      command_new([path || Dir.pwd])
      0
    end
  end
end
