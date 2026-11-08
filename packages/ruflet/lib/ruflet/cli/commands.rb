# frozen_string_literal: true

module Ruflet
  module CLI
    # Every `ruflet` command, in the order `ruflet help` lists them.
    #
    # A command declares:
    #
    # * name and aliases: the words that run it. `Ruflet::CLI.run` downcases
    #   the first argument and looks it up here.
    # * handler: the Ruflet::CLI method that runs it, given the arguments after
    #   the word. Its result is the exit status.
    # * usage: its line under "Commands:" in `ruflet help` (nil: not listed).
    # * options: the flags it reads itself, as OptionParser#on switch strings.
    # * forwards: the tool that receives the arguments it does not read.
    # * help: sections `ruflet help` prints after the command list.
    # * first_run_assets: whether the Flutter template is fetched before it runs.
    #
    # A new command registers itself beside its code, with `before:` or
    # `after:` when the end of the list is not the right place:
    #
    #   Commands.register(
    #     "logs",
    #     handler: :command_logs,
    #     usage: "ruflet logs [-d DEVICE_ID]",
    #     options: [Commands.option("-d", "--device DEVICE_ID", description: "Device to read")],
    #     after: "emulators"
    #   )
    #
    # Nothing parses with the declared options yet: each command still reads
    # its own arguments, and cli_commands_test checks that the declarations
    # are exactly what it reads. They are what per-command usage and
    # unknown-flag errors (CLI-12) are to be built from.
    module Commands
      TITLE = "Ruflet CLI"
      HELP_TERM_WIDTH = 16

      Option = Struct.new(:switches, :description, keyword_init: true)
      Section = Struct.new(:title, :rows, keyword_init: true)
      Command = Struct.new(
        :name, :aliases, :handler, :usage, :options, :forwards, :help, :first_run_assets,
        keyword_init: true
      ) do
        def words
          [name, *aliases]
        end
      end

      class Registry
        def initialize
          @commands = []
        end

        # Registering the same command again changes nothing, so a reloaded
        # file cannot duplicate it.
        def register(name, handler:, aliases: [], usage: nil, options: [], forwards: nil, help: [],
                     first_run_assets: false, before: nil, after: nil)
          raise ArgumentError, "pass before: or after:, not both" if before && after

          command = Command.new(
            name: command_word(name),
            aliases: Array(aliases).map { |word| command_word(word) }.freeze,
            handler: handler.to_sym,
            usage: frozen_text(usage),
            options: Array(options).dup.freeze,
            forwards: frozen_text(forwards),
            help: Array(help).dup.freeze,
            first_run_assets: first_run_assets ? true : false
          ).freeze

          existing = @commands.find { |entry| entry.name == command.name }
          if existing
            return existing if existing == command

            raise ArgumentError, "ruflet command #{command.name} is already registered"
          end
          words = command.words
          raise ArgumentError, "ruflet command #{command.name} repeats a word" unless words.uniq.length == words.length

          words.each do |word|
            owner = lookup(word)
            raise ArgumentError, "ruflet command word #{word} already runs #{owner.name}" if owner
          end

          index =
            if before
              position(before)
            elsif after
              position(after) + 1
            else
              @commands.length
            end
          @commands.insert(index, command)
          command
        end

        # The command a word runs: an exact match on a name or alias.
        def lookup(word)
          @commands.find { |command| command.words.include?(word) }
        end

        def commands
          @commands.dup.freeze
        end

        def names
          @commands.map(&:name)
        end

        def words
          @commands.flat_map(&:words)
        end

        def help_text
          lines = [TITLE, "", "Commands:"]
          @commands.each { |command| lines << "  #{command.usage}" if command.usage }
          @commands.each do |command|
            command.help.each do |section|
              lines << ""
              lines << "#{section.title}:"
              section.rows.each { |term, text| lines << format("  %-#{HELP_TERM_WIDTH}s %s", term, text) }
            end
          end
          "#{lines.join("\n")}\n"
        end

        private

        def command_word(value)
          word = value.to_s
          unless !word.empty? && word == word.downcase && !word.match?(/\s/)
            raise ArgumentError, "invalid ruflet command word #{value.inspect} (lowercase, no spaces)"
          end

          word.dup.freeze
        end

        def frozen_text(value)
          value&.to_s&.dup&.freeze
        end

        def position(name)
          index = @commands.index { |command| command.name == name.to_s }
          raise ArgumentError, "unknown ruflet command #{name}" unless index

          index
        end
      end

      @registry = Registry.new

      class << self
        attr_reader :registry

        def register(name, **declaration)
          registry.register(name, **declaration)
        end

        def lookup(word)
          registry.lookup(word)
        end

        def commands
          registry.commands
        end

        def names
          registry.names
        end

        def words
          registry.words
        end

        def help_text
          registry.help_text
        end

        def option(*switches, description: nil)
          Option.new(switches: switches.map { |switch| switch.to_s.dup.freeze }.freeze, description: description).freeze
        end

        def section(title, rows)
          Section.new(title: title, rows: rows.map { |row| row.dup.freeze }.freeze).freeze
        end
      end

      # --- the commands -------------------------------------------------------

      verbose = option("-v", "--verbose", description: "Print each step and run Flutter with -v")

      register(
        "version",
        aliases: %w[-v --version],
        handler: :command_version,
        usage: "ruflet --version"
      )
      register(
        "create",
        handler: :command_create,
        usage: "ruflet create <appname>",
        first_run_assets: true
      )
      register(
        "new",
        aliases: %w[bootstrap init],
        handler: :command_new,
        usage: "ruflet new <appname>",
        first_run_assets: true
      )
      register(
        "run",
        handler: :command_run,
        usage: "ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]",
        options: [
          option("--web", description: "Serve the web client and open it in a browser"),
          option("--desktop", description: "Open the app in the desktop client"),
          option("--port PORT", description: "Port to serve on (default 8550); the next free one if it is taken"),
          option("--no-reload", description: "Turn off hot reload")
        ]
      )
      register(
        "update",
        handler: :command_update,
        usage: "ruflet update [web|desktop|all] [--check] [--force] [--platform PLATFORM]",
        options: [
          option("--web", description: "Update the web client"),
          option("--desktop", description: "Update the desktop client"),
          option("--check", description: "Report which clients are installed instead of updating them"),
          option("--force", description: "Download the template and clients again"),
          option("--platform PLATFORM", description: "macos, linux or windows (default: this host)")
        ],
        first_run_assets: true
      )
      register(
        "debug",
        handler: :command_debug,
        usage: "ruflet debug [scriptname|path]",
        options: [
          option("--platform NAME", description: "web, ios, android, macos, windows or linux"),
          option("--device-id ID", description: "Flutter device to run on"),
          option("--release", description: "Run a release build"),
          option("-v", "--verbose", description: "Run Flutter with -v"),
          option("--web-renderer NAME", description: "Passed to flutter run as --web-renderer")
        ],
        first_run_assets: true
      )
      register(
        "build",
        handler: :command_build,
        usage: "ruflet build <apk|android|ios|ipa|aab|web|macos|windows|linux> [--lite|--full|--self] [--verbose]",
        options: [
          option("--self", description: "Self-contained lite build (default profile)"),
          option("--lite", description: "Self-contained lite build"),
          option("--full", description: "Self-contained full CRuby build with locked project gems"),
          verbose
        ],
        forwards: "flutter build <target>",
        help: [
          section(
            "Build profiles",
            [
              ["--self", "Self-contained lite build (default profile)"],
              ["--self --full", "Self-contained full CRuby build with locked project gems"],
              ["--full", "Also implies --self"]
            ]
          )
        ],
        first_run_assets: true
      )
      register(
        "install",
        handler: :command_install,
        usage: "ruflet install [--device DEVICE_ID] [--verbose]",
        options: [
          verbose,
          option("-d", "--device DEVICE_ID", description: "Device to install on")
        ],
        first_run_assets: true
      )
      register(
        "devices",
        handler: :command_devices,
        usage: "ruflet devices",
        forwards: "flutter devices"
      )
      register(
        "emulators",
        handler: :command_emulators,
        usage: "ruflet emulators",
        options: [
          option("--create", description: "Not implemented yet"),
          option("--delete", description: "Not implemented yet"),
          option("--start", description: "Launch the emulator named by --emulator"),
          option("--emulator ID", description: "Emulator to start"),
          option("-v", "--verbose", description: "Run Flutter with -v")
        ]
      )
      register(
        "doctor",
        handler: :command_doctor,
        usage: "ruflet doctor [--fix] [--verbose]",
        options: [
          option("-v", "--verbose", description: "Run flutter doctor with -v"),
          option("--fix", description: "Fetch the template again and install Flutter if it is missing")
        ],
        first_run_assets: true
      )
      register(
        "help",
        aliases: %w[-h --help],
        handler: :command_help
      )
    end
  end
end
