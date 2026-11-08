# frozen_string_literal: true

require "optparse"

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
    # * synopsis: the usage lines `ruflet help <command>` prints (default: usage).
    # * summary: what it does, one sentence, under the synopsis.
    # * unknown_flags: who reports a flag the command does not read:
    #     :reject   `Ruflet::CLI.run` does, before the command runs (the
    #               command reads its flags by exact match);
    #     :command  the command does (its OptionParser, or its own check);
    #     :forward  nobody: they go to `forwards`.
    # * help_flags: where -h/--help shows the command's help instead of
    #   reaching it: :anywhere, :before_positional (`build --help`, while
    #   `build apk --help` is flutter's) or :never (the command handles them).
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
    # Each command still reads its own arguments; cli_commands_test checks
    # that the declarations are exactly what it reads. `ruflet help <command>`
    # and the usage a bad flag prints are rendered from them.
    module Commands
      TITLE = "Ruflet CLI"
      HELP_TERM_WIDTH = 16
      # sysexits(3) EX_USAGE, which flutter also exits with for a bad flag.
      EX_USAGE = 64
      HELP_SWITCHES = %w[-h --help].freeze
      UNKNOWN_FLAGS = %i[reject command forward].freeze
      HELP_FLAGS = %i[anywhere before_positional never].freeze

      # Raised by a command's own parser for -h/--help (or an abbreviation of
      # it), so `ruflet <command> --help` prints what `ruflet help <command>` does.
      class HelpRequested < StandardError; end

      # A usage mistake OptionParser cannot see, such as a flag that needs
      # another one. Reported like an unknown flag.
      class UsageError < StandardError; end

      # hidden: switches the command still accepts but `ruflet help` does not
      # list, such as abbreviations that worked before a longer flag existed.
      Option = Struct.new(:switches, :description, :hidden, keyword_init: true) do
        # The flag words, without the value placeholder: "--port PORT" is "--port".
        def words
          (switches + hidden).map { |switch| switch.split(" ", 2).first }
        end

        def value?
          switches.any? { |switch| switch.include?(" ") }
        end

        def label
          switches.join(", ")
        end
      end
      Section = Struct.new(:title, :rows, keyword_init: true)
      Command = Struct.new(
        :name, :aliases, :handler, :usage, :options, :forwards, :help, :first_run_assets,
        :synopsis, :summary, :unknown_flags, :help_flags,
        keyword_init: true
      ) do
        def words
          [name, *aliases]
        end

        # Whether -h/--help in these arguments asks for this command's help.
        def help_requested?(args)
          return false if help_flags == :never

          args.each do |arg|
            break if arg == "--"
            return true if HELP_SWITCHES.include?(arg)
            return false if help_flags == :before_positional && !Commands.flag?(arg)
          end
          false
        end

        # Raises OptionParser::ParseError for the first flag in args this
        # command does not read. Flags are matched exactly, as the commands
        # that declare unknown_flags: :reject read them; a flag that takes a
        # value takes the next argument, or `--flag=value`.
        def check_flags!(args)
          return unless unknown_flags == :reject

          index = 0
          while index < args.length
            arg = args[index]
            break if arg == "--"

            index += 1
            next unless Commands.flag?(arg)

            word, value = arg.start_with?("--") ? arg.split("=", 2) : [arg, nil]
            next if value.nil? && HELP_SWITCHES.include?(word)

            option = options.find { |candidate| candidate.words.include?(word) }
            raise OptionParser::InvalidOption, arg unless option

            if option.value?
              raise OptionParser::MissingArgument, arg if value&.empty?
              next if value
              raise OptionParser::MissingArgument, arg if index >= args.length

              index += 1
            elsif value
              raise OptionParser::NeedlessArgument, arg
            end
          end
        end

        # What `ruflet help <command>` and `ruflet <command> --help` print.
        def help_text
          lines = []
          (synopsis || [usage || "ruflet #{name}"]).each_with_index do |line, index|
            lines << (index.zero? ? "Usage: #{line}" : "       #{line}")
          end
          if summary
            lines << ""
            lines << summary
          end
          shown_aliases = aliases.reject { |word| Commands.flag?(word) }
          unless shown_aliases.empty?
            lines << ""
            lines << "Aliases: #{shown_aliases.join(', ')}"
          end
          listed = options.dup
          listed << HELP_OPTION unless help_flags == :never
          unless listed.empty?
            width = [listed.map { |option| option.label.length }.max + 2, HELP_TERM_WIDTH].max
            lines << ""
            lines << "Options:"
            listed.each { |option| lines << format("  %-#{width}s %s", option.label, option.description).rstrip }
          end
          if forwards
            lines << ""
            lines << "Other arguments are passed to `#{forwards}`."
          end
          help.each do |section|
            lines << ""
            lines << "#{section.title}:"
            section.rows.each { |term, text| lines << format("  %-#{HELP_TERM_WIDTH}s %s", term, text) }
          end
          "#{lines.join("\n")}\n"
        end
      end

      class Registry
        def initialize
          @commands = []
        end

        # Registering the same command again changes nothing, so a reloaded
        # file cannot duplicate it.
        def register(name, handler:, aliases: [], usage: nil, options: [], forwards: nil, help: [],
                     first_run_assets: false, synopsis: nil, summary: nil, unknown_flags: :reject,
                     help_flags: :anywhere, before: nil, after: nil)
          raise ArgumentError, "pass before: or after:, not both" if before && after
          raise ArgumentError, "unknown_flags: must be one of #{UNKNOWN_FLAGS.inspect}" unless UNKNOWN_FLAGS.include?(unknown_flags)
          raise ArgumentError, "help_flags: must be one of #{HELP_FLAGS.inspect}" unless HELP_FLAGS.include?(help_flags)

          command = Command.new(
            name: command_word(name),
            aliases: Array(aliases).map { |word| command_word(word) }.freeze,
            handler: handler.to_sym,
            usage: frozen_text(usage),
            options: Array(options).dup.freeze,
            forwards: frozen_text(forwards),
            help: Array(help).dup.freeze,
            first_run_assets: first_run_assets ? true : false,
            synopsis: synopsis && Array(synopsis).map { |line| frozen_text(line) }.freeze,
            summary: frozen_text(summary),
            unknown_flags: unknown_flags,
            help_flags: help_flags
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

        def option(*switches, description: nil, hidden: [])
          Option.new(
            switches: switches.map { |switch| switch.to_s.dup.freeze }.freeze,
            description: description,
            hidden: Array(hidden).map { |switch| switch.to_s.dup.freeze }.freeze
          ).freeze
        end

        # An argument that names a flag: "-x", "--x", "--x=v"; not "-" alone.
        def flag?(arg)
          arg.start_with?("-") && arg != "-"
        end

        def section(title, rows)
          Section.new(title: title, rows: rows.map { |row| row.dup.freeze }.freeze).freeze
        end
      end

      # Listed for every command whose -h/--help shows its help.
      HELP_OPTION = option("-h", "--help", description: "Show this help")

      # --- the commands -------------------------------------------------------

      verbose = option("-v", "--verbose", description: "Print each step and run Flutter with -v")

      register(
        "version",
        aliases: %w[-v --version],
        handler: :command_version,
        usage: "ruflet --version",
        synopsis: ["ruflet --version", "ruflet -v", "ruflet version"],
        summary: "Print the installed Ruflet version."
      )
      register(
        "create",
        handler: :command_create,
        usage: "ruflet create <appname>",
        summary: "Create a Ruflet app in ./<appname>, as `ruflet new` does.",
        first_run_assets: true
      )
      register(
        "new",
        aliases: %w[bootstrap init],
        handler: :command_new,
        usage: "ruflet new <appname>",
        summary: "Create a Ruflet app in ./<appname>: main.rb, Gemfile, ruflet.yaml and starter assets.",
        first_run_assets: true
      )
      register(
        "run",
        handler: :command_run,
        usage: "ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]",
        summary: "Serve the app with hot reload, for Ruflet Explorer (the default), the web client or the desktop client.",
        options: [
          option("--web", description: "Serve the web client and open it in a browser"),
          # -d is --desktop. --device would make a bare -d ambiguous, so it is
          # declared; --d and --de keep reaching --desktop as they did before.
          option("-d", "--desktop", description: "Open the app in the desktop client", hidden: %w[--de --d]),
          option("--port PORT", description: "Port to serve on (default 8550); the next free one if it is taken"),
          option("--no-reload", description: "Turn off hot reload"),
          option("--device ID", description: "Run on a Flutter device (not supported yet)")
        ],
        unknown_flags: :command
      )
      register(
        "update",
        handler: :command_update,
        usage: "ruflet update [web|desktop|all] [--check] [--force] [--platform PLATFORM]",
        summary: "Download the prebuilt web and desktop clients, or check which are installed.",
        options: [
          option("--web", description: "Update the web client"),
          option("--desktop", description: "Update the desktop client"),
          option("--check", description: "Report which clients are installed instead of updating them"),
          option("--force", description: "Download the template and clients again"),
          option("--platform PLATFORM", description: "macos, linux or windows (default: this host)")
        ],
        unknown_flags: :command,
        first_run_assets: true
      )
      register(
        "debug",
        handler: :command_debug,
        usage: "ruflet debug [scriptname|path]",
        synopsis: ["ruflet debug [platform] [--platform NAME] [--device ID] [--release] [-v|--verbose] [--web-renderer NAME]"],
        summary: "Run the Flutter client in build/client with `flutter run`.",
        options: [
          option("--platform NAME", description: "web, ios, android, macos, windows or linux"),
          option("--device ID", "--device-id ID", description: "Flutter device to run on"),
          option("--release", description: "Run a release build"),
          option("-v", "--verbose", description: "Run Flutter with -v"),
          option("--web-renderer NAME", description: "Passed to flutter run as --web-renderer")
        ],
        unknown_flags: :command,
        first_run_assets: true
      )
      register(
        "build",
        handler: :command_build,
        usage: "ruflet build <apk|android|ios|ipa|aab|web|macos|windows|linux> [--lite|--full|--self] [--verbose]",
        summary: "Build the app for one platform. The target may come before or after the flags.",
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
        unknown_flags: :forward,
        help_flags: :before_positional,
        first_run_assets: true
      )
      register(
        "install",
        handler: :command_install,
        usage: "ruflet install [--device DEVICE_ID] [--verbose]",
        summary: "Install the last build from ./build on a device; without --device, pick one from a list.",
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
        summary: "List the devices Flutter can run on.",
        forwards: "flutter devices",
        unknown_flags: :forward,
        help_flags: :never
      )
      register(
        "emulators",
        handler: :command_emulators,
        usage: "ruflet emulators",
        synopsis: ["ruflet emulators [-v|--verbose]", "ruflet emulators --start --emulator ID [--cold] [-v|--verbose]"],
        summary: "List the configured emulators, or start one.",
        options: [
          option("--create", description: "Not implemented yet"),
          option("--delete", description: "Not implemented yet"),
          option("--start", description: "Launch the emulator named by --emulator"),
          option("--emulator ID", description: "Emulator to start"),
          option("--cold", description: "With --start: cold boot the emulator (Android only)"),
          option("-v", "--verbose", description: "Run Flutter with -v")
        ],
        unknown_flags: :command
      )
      register(
        "doctor",
        handler: :command_doctor,
        usage: "ruflet doctor [--fix] [--verbose]",
        summary: "Report Ruby, the Flutter template and the Flutter SDK, then run `flutter doctor`.",
        options: [
          option("-v", "--verbose", description: "Run flutter doctor with -v"),
          option("--fix", description: "Fetch the template again and install Flutter if it is missing")
        ],
        first_run_assets: true
      )
      register(
        "help",
        aliases: %w[-h --help],
        handler: :command_help,
        synopsis: ["ruflet help [command]"],
        summary: "Show the commands, or one command's usage and options.",
        unknown_flags: :command,
        help_flags: :never
      )
    end
  end
end
