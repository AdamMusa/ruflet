# frozen_string_literal: true

require_relative "test_helper"

# Pins how `Ruflet::CLI.run` turns the first argument into a command: which
# words reach which command method, with which arguments, which commands fetch
# the first-run assets beforehand, what `help` prints and every exit code.
# The commands themselves are replaced by recorders on a private copy of the
# CLI, so nothing here touches Ruflet::CLI or runs a real command.
class RufletCliDispatchTest < Minitest::Test
  HELP = <<~HELP
    Ruflet CLI

    Commands:
      ruflet --version
      ruflet create <appname>
      ruflet new <appname>
      ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]
      ruflet update [web|desktop|all] [--check] [--force] [--platform PLATFORM]
      ruflet debug [scriptname|path]
      ruflet build <apk|android|ios|ipa|aab|web|macos|windows|linux> [--lite|--full|--self] [--verbose]
      ruflet install [--device DEVICE_ID] [--verbose]
      ruflet devices
      ruflet emulators
      ruflet doctor [--fix] [--verbose]

    Build profiles:
      --self           Self-contained lite build (default profile)
      --self --full    Self-contained full CRuby build with locked project gems
      --full           Also implies --self
  HELP

  # Every word `ruflet` accepts as a command, and the method it runs.
  HANDLERS = {
    "create" => :command_create,
    "new" => :command_new,
    "bootstrap" => :command_new,
    "init" => :command_new,
    "run" => :command_run,
    "update" => :command_update,
    "debug" => :command_debug,
    "build" => :command_build,
    "install" => :command_install,
    "devices" => :command_devices,
    "emulators" => :command_emulators,
    "doctor" => :command_doctor
  }.freeze
  VERSION_WORDS = %w[version -v --version].freeze
  HELP_WORDS = %w[help -h --help].freeze
  # The words that fetch the Flutter template on first use before they run.
  FIRST_RUN_ASSET_WORDS = %w[create new bootstrap init update debug build install doctor].freeze
  ALL_WORDS = (HANDLERS.keys + VERSION_WORDS + HELP_WORDS).freeze

  # A copy of Ruflet::CLI's own dispatch whose commands and asset download
  # only record what they were given.
  class RecordingCli
    attr_reader :calls, :asset_fetches

    def initialize(result: 0, fetch_error: nil)
      @calls = []
      @asset_fetches = 0
      @result = result
      @fetch_error = fetch_error
      extend Ruflet::CLI
      HANDLERS.values.uniq.each do |handler|
        define_singleton_method(handler) do |args|
          @calls << [handler, args]
          @result
        end
      end
    end

    private

    def download_ruflet_assets(*)
      @asset_fetches += 1
      raise @fetch_error if @fetch_error

      true
    end
  end

  def test_help_text_is_unchanged
    out, err = capture_io { Ruflet::CLI.print_help }

    assert_equal HELP, out
    assert_empty err
  end

  def test_every_command_word_runs_its_command_with_the_remaining_arguments
    HANDLERS.each do |word, handler|
      cli = RecordingCli.new(result: 7)
      # A flag the command does not read reaches only the commands that parse
      # their own flags or forward them; for the others it is a usage error
      # before the command runs (CLI-12, cli_usage_test).
      rest = Ruflet::CLI::Commands.lookup(word).unknown_flags == :reject ? %w[target value] : %w[target --flag value]
      argv = [word, *rest]
      code = nil
      out, err = capture_io { code = cli.run(argv) }

      assert_equal 7, code, "#{word}: the command's result is the exit code"
      assert_equal [[handler, rest]], cli.calls, word
      assert_same argv, cli.calls.first.last, "#{word}: the command gets the caller's argv, minus the word"
      assert_empty out, word
      assert_empty err, word
    end
  end

  def test_command_words_match_in_any_case
    ALL_WORDS.each do |word|
      [word.upcase, word.capitalize, word.swapcase].uniq.each do |variant|
        expected = RecordingCli.new
        actual = RecordingCli.new
        expected_out = capture_io { expected.run([word, "arg"]) }
        actual_out = capture_io { actual.run([variant, "arg"]) }

        assert_equal expected.calls, actual.calls, variant
        assert_equal expected.asset_fetches, actual.asset_fetches, variant
        assert_equal expected_out, actual_out, variant
      end
    end
  end

  # (--help after them prints the version command's help since CLI-12.)
  def test_version_words_print_the_version_and_ignore_further_arguments
    VERSION_WORDS.each do |word|
      cli = RecordingCli.new
      code = nil
      out, err = capture_io { code = cli.run([word, "extra", "more"]) }

      assert_equal 0, code, word
      assert_equal "ruflet #{Ruflet::VERSION}\n", out, word
      assert_empty err, word
      assert_empty cli.calls, word
    end
  end

  # (`help build` prints build's help since CLI-12; see cli_usage_test.)
  def test_help_words_and_no_arguments_print_help
    [*HELP_WORDS.map { |word| [word] }, [], %w[help bogus], %w[--help bogus]].each do |argv|
      cli = RecordingCli.new
      code = nil
      out, err = capture_io { code = cli.run(argv.dup) }

      assert_equal 0, code, argv.inspect
      assert_equal HELP, out, argv.inspect
      assert_empty err, argv.inspect
      assert_empty cli.calls, argv.inspect
    end
  end

  def test_an_unknown_command_names_the_downcased_word_prints_help_and_exits_1
    { "pack" => "pack", "Bogus-Command" => "bogus-command", "" => "", "-x" => "-x", "versions" => "versions" }.each do |word, shown|
      cli = RecordingCli.new
      code = nil
      out, err = capture_io { code = cli.run([word, "build"]) }

      assert_equal 1, code, word.inspect
      assert_equal "Unknown command: #{shown}\n", err, word.inspect
      assert_equal HELP, out, word.inspect
      assert_empty cli.calls, word.inspect
      assert_equal 0, cli.asset_fetches, word.inspect
    end
  end

  def test_only_commands_that_create_or_build_fetch_first_run_assets
    ALL_WORDS.each do |word|
      cli = RecordingCli.new
      capture_io { cli.run([word]) }

      expected = FIRST_RUN_ASSET_WORDS.include?(word) ? 1 : 0
      assert_equal expected, cli.asset_fetches, word
    end
  end

  def test_a_failed_asset_fetch_does_not_stop_the_command
    cli = RecordingCli.new(result: 0, fetch_error: StandardError.new("offline"))
    code = nil
    out, err = capture_io { code = cli.run(%w[build apk]) }

    assert_equal 0, code
    assert_equal 1, cli.asset_fetches
    assert_equal [[:command_build, %w[apk]]], cli.calls
    assert_empty out
    assert_empty err
  end

  def test_the_cli_itself_runs_every_command_method
    HANDLERS.values.uniq.each do |handler|
      assert Ruflet::CLI.respond_to?(handler), "Ruflet::CLI.#{handler}"
    end
    assert Ruflet::CLI.respond_to?(:print_help)
    assert Ruflet::CLI.respond_to?(:version_string)
    assert Ruflet::CLI.respond_to?(:bootstrap)
    assert Ruflet::CLI.respond_to?(:download_ruflet_assets, true)
  end
end
