# frozen_string_literal: true

require_relative "test_helper"
require_relative "cli_dispatch_test"

# The command registry `Ruflet::CLI.run` dispatches through and `ruflet help`
# renders: the built-in table, the registration API later commands use, and
# that each command's declared options are exactly the ones it reads today.
class RufletCliCommandsTest < Minitest::Test
  Commands = Ruflet::CLI::Commands
  Dispatch = RufletCliDispatchTest

  # --- the built-in table ---------------------------------------------------

  def test_commands_are_listed_in_help_order
    assert_equal %w[version create new run update debug build install devices emulators doctor help], Commands.names
  end

  def test_every_word_maps_to_the_command_method_it_ran_before
    expected = Dispatch::HANDLERS.merge(
      Dispatch::VERSION_WORDS.to_h { |word| [word, :command_version] },
      Dispatch::HELP_WORDS.to_h { |word| [word, :command_help] }
    )

    assert_equal expected.keys.sort, Commands.words.sort
    expected.each do |word, handler|
      assert_equal handler, Commands.lookup(word)&.handler, word
    end
  end

  def test_lookup_is_exact
    # Ruflet::CLI.run downcases the word first; the table holds lowercase words.
    %w[VERSION Build -V bogus].push("", " build").each do |word|
      assert_nil Commands.lookup(word), word.inspect
    end
  end

  def test_first_run_assets_are_declared_by_the_commands_that_fetched_them
    fetching = Commands.words.select { |word| Commands.lookup(word).first_run_assets }

    assert_equal Dispatch::FIRST_RUN_ASSET_WORDS.sort, fetching.sort
  end

  def test_the_help_text_is_rendered_from_the_table
    assert_equal Dispatch::HELP, Commands.help_text
  end

  def test_help_itself_has_no_usage_line
    assert_nil Commands.lookup("help").usage
    assert_equal "ruflet --version", Commands.lookup("version").usage
  end

  def test_every_handler_is_a_cli_method
    Commands.commands.each do |command|
      assert Ruflet::CLI.respond_to?(command.handler, true), "Ruflet::CLI must respond to #{command.handler}"
      assert_equal 1, Ruflet::CLI.method(command.handler).arity, "#{command.handler} takes the remaining argv"
    end
  end

  def test_the_table_is_frozen
    assert_predicate Commands.commands, :frozen?
    Commands.commands.each do |command|
      assert_predicate command, :frozen?, command.name
      assert_predicate command.aliases, :frozen?, command.name
      assert_predicate command.options, :frozen?, command.name
      assert_predicate command.help, :frozen?, command.name
    end
  end

  def test_only_build_and_devices_forward_their_remaining_arguments
    forwards = Commands.commands.to_h { |command| [command.name, command.forwards] }.compact

    assert_equal({ "build" => "flutter build <target>", "devices" => "flutter devices" }, forwards)
  end

  # --- declared options match what each command reads ----------------------

  # Captures the OptionParser a command builds, when this thread asks for it,
  # instead of letting it parse.
  module ParserCapture
    def parse!(*args, **kwargs)
      sink = Thread.current[:ruflet_commands_test_parsers]
      return super unless sink

      sink << self
      throw :ruflet_commands_test_parsed
    end
  end
  OptionParser.prepend(ParserCapture)

  # Records which flags a hand-parsing command looks for.
  class ArgsSpy < Array
    def deleted
      @deleted ||= []
    end

    def delete(item, &block)
      deleted << item
      super
    end
  end

  def test_option_parser_commands_declare_exactly_their_switches
    %w[run update debug emulators].each do |name|
      command = Commands.lookup(name)
      parser = captured_parser(command.handler)
      # Each parser also takes -h/--help, which raises Commands::HelpRequested.
      declared = OptionParser.new do |o|
        [*command.options, Commands::HELP_OPTION].each { |option| o.on(*option.switches, *option.hidden) {} }
      end

      assert_equal parser.summarize, declared.summarize, "#{name} options"
    end
  end

  def test_hand_parsed_commands_declare_exactly_the_flags_they_read
    {
      "build" => { stop: nil },
      "install" => { stop: :ensure_flutter_client_dir },
      "doctor" => { stop: :detect_client_dir }
    }.each do |name, spec|
      command = Commands.lookup(name)
      host = command_host
      extracted = []
      host.define_singleton_method(:extract_option_value!) do |_args, *flags|
        extracted.concat(flags)
        nil
      end
      host.define_singleton_method(spec[:stop]) { |*, **| throw :ruflet_commands_test_parsed } if spec[:stop]
      args = ArgsSpy.new
      capture_io { catch(:ruflet_commands_test_parsed) { host.public_send(command.handler, args) } }

      flags = ->(takes_value) { command.options.select { |o| value?(o) == takes_value }.flat_map { |o| words(o) } }
      assert_equal args.deleted.sort, flags.call(false).sort, "#{name} boolean flags"
      assert_equal extracted.sort, flags.call(true).sort, "#{name} flags with a value"
    end
  end

  def test_commands_without_options_declare_none
    %w[version create new devices help].each do |name|
      assert_empty Commands.lookup(name).options, name
    end
  end

  def test_devices_forwards_every_argument_to_flutter_devices
    host = command_host
    host.define_singleton_method(:ensure_flutter!) { |*, **| { flutter: "flutter", env: {} } }
    ran = nil
    host.define_singleton_method(:system) do |*argv, **|
      ran = argv
      true
    end
    system("true") # command_devices reads $? after its (stubbed) system call
    host.command_devices(%w[--machine -d emulator-5554])

    assert_equal [{}, "flutter", "devices", "--machine", "-d", "emulator-5554"], ran
  end

  # --- the registration API ---------------------------------------------------

  def test_register_appends_and_positions_with_before_or_after
    assert_respond_to Commands, :register
    registry = Commands::Registry.new
    registry.register("a", handler: :command_a)
    registry.register("c", handler: :command_c)
    registry.register("b", handler: :command_b, after: "a")
    registry.register("start", handler: :command_start, before: "a")

    assert_equal %w[start a b c], registry.names
  end

  def test_register_accepts_an_identical_registration_again
    registry = Commands::Registry.new
    first = registry.register("logs", handler: :command_logs, aliases: %w[log], usage: "ruflet logs")
    again = registry.register("logs", handler: :command_logs, aliases: %w[log], usage: "ruflet logs")

    assert_same first, again
    assert_equal %w[logs], registry.names
  end

  def test_register_rejects_conflicts
    registry = Commands::Registry.new
    registry.register("logs", handler: :command_logs, aliases: %w[log])

    assert_raises(ArgumentError) { registry.register("logs", handler: :command_other) }
    assert_raises(ArgumentError) { registry.register("other", handler: :command_other, aliases: %w[log]) }
    assert_raises(ArgumentError) { registry.register("log", handler: :command_other) }
    assert_raises(ArgumentError) { registry.register("twice", handler: :command_twice, aliases: %w[twice]) }
    assert_raises(ArgumentError) { registry.register("Upper", handler: :command_upper) }
    assert_raises(ArgumentError) { registry.register("", handler: :command_empty) }
    assert_raises(ArgumentError) { registry.register("two words", handler: :command_two) }
    assert_raises(ArgumentError) { registry.register("x", handler: :command_x, before: "logs", after: "logs") }
    assert_raises(ArgumentError) { registry.register("x", handler: :command_x, after: "missing") }
    assert_equal %w[logs], registry.names
  end

  def test_lookup_finds_names_and_aliases
    registry = Commands::Registry.new
    command = registry.register("logs", handler: :command_logs, aliases: %w[log -l])

    assert_same command, registry.lookup("logs")
    assert_same command, registry.lookup("log")
    assert_same command, registry.lookup("-l")
    assert_nil registry.lookup("logz")
    assert_equal %w[logs log -l], registry.words
  end

  def test_help_text_lists_usage_lines_then_help_sections
    registry = Commands::Registry.new
    registry.register("logs", handler: :command_logs, usage: "ruflet logs [-d DEVICE_ID]")
    registry.register("hidden", handler: :command_hidden)
    registry.register(
      "clean", handler: :command_clean, usage: "ruflet clean [--all]",
      help: [Commands.section("Clean targets", [["--all", "Remove ./build"], ["--a-very-long-term", "Still one space"]])]
    )

    assert_equal <<~HELP, registry.help_text
      Ruflet CLI

      Commands:
        ruflet logs [-d DEVICE_ID]
        ruflet clean [--all]

      Clean targets:
        --all            Remove ./build
        --a-very-long-term Still one space
    HELP
  end

  def test_option_and_section_helpers
    option = Commands.option("-d", "--device DEVICE_ID", description: "Device to use")

    assert_equal ["-d", "--device DEVICE_ID"], option.switches
    assert_equal "Device to use", option.description
    assert_predicate option, :frozen?
    section = Commands.section("Title", [%w[a b]])
    assert_equal "Title", section.title
    assert_equal [%w[a b]], section.rows
    assert_predicate section, :frozen?
  end

  private

  def command_host
    host = Object.new
    [
      Ruflet::CLI::NewCommand,
      Ruflet::CLI::RunCommand,
      Ruflet::CLI::UpdateCommand,
      Ruflet::CLI::BuildCommand,
      Ruflet::CLI::ExtraCommand
    ].each { |mod| host.extend(mod) }
    host
  end

  def captured_parser(handler)
    host = command_host
    host.define_singleton_method(:ensure_flutter!) { |*, **| { flutter: "flutter", env: {} } }
    sink = []
    Thread.current[:ruflet_commands_test_parsers] = sink
    catch(:ruflet_commands_test_parsed) { host.public_send(handler, []) }
    assert_equal 1, sink.length, "#{handler} builds one OptionParser"
    sink.first
  ensure
    Thread.current[:ruflet_commands_test_parsers] = nil
  end

  def words(option)
    option.switches.map { |switch| switch.split(" ", 2).first }
  end

  def value?(option)
    option.switches.any? { |switch| switch.include?(" ") }
  end
end
