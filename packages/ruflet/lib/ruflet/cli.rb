# frozen_string_literal: true

require "optparse"

require_relative "version"
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

    def run(argv = ARGV)
      command = (argv.shift || "help").downcase
      ensure_first_run_assets(command)

      case command
      when "version", "-v", "--version"
        puts version_string
        0
      when "create"
        command_create(argv)
      when "new", "bootstrap", "init"
        command_new(argv)
      when "run"
        command_run(argv)
      when "update"
        command_update(argv)
      when "debug"
        command_debug(argv)
      when "build"
        command_build(argv)
      when "install"
        command_install(argv)
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
    rescue OptionParser::ParseError => e
      # An unknown flag or a bad value (`run --port abc`) is a usage error,
      # not a crash: say which and exit 1 instead of printing a backtrace.
      warn "ruflet #{command}: #{e.message}"
      warn "Run `ruflet help` for usage."
      1
    end

    def print_help
      puts <<~HELP
        Ruflet CLI

        Commands:
          ruflet --version                 (also: version, -v)
          ruflet create <appname>
          ruflet new <appname>             (also: bootstrap, init)
          ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]
          ruflet update [web|desktop|all|check] [--web] [--desktop] [--check] [--force] [--platform macos|linux|windows]
          ruflet debug [web|macos|windows|linux|ios|android] [--platform NAME] [--device-id ID] [--release] [--web-renderer NAME] [--verbose]
          ruflet build <apk|android|aab|appbundle|ios|ipa|web|macos|windows|linux> [--lite|--full|--self] [--verbose] [flutter args...]
          ruflet install [--device|-d DEVICE_ID] [--verbose]
          ruflet devices [flutter args...]
          ruflet emulators [--start --emulator ID] [--verbose]
          ruflet doctor [--fix] [--verbose]
          ruflet help                      (also: -h, --help)

        Build profiles:
          (none)           Server-driven client; mobile targets need backend_url in ruflet.yaml
          --self           Self-contained build with the embedded lite runtime
          --self --full    Self-contained full CRuby build with locked project gems
          --lite, --full   Each implies --self
      HELP
    end

    def bootstrap(path)
      command_new([path || Dir.pwd])
    end

    def version_string
      "ruflet #{Ruflet::VERSION}"
    end

    private

    def ensure_first_run_assets(command)
      return unless %w[create new bootstrap init update debug build install doctor].include?(command)
      return unless respond_to?(:download_ruflet_assets, true)

      send(:download_ruflet_assets)
    rescue StandardError
      nil
    end
  end
end
