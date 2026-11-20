# frozen_string_literal: true

require_relative "test_helper"

# CLI-12: what every command does with a flag it does not read, with -h/--help,
# and with `ruflet help <command>`; plus the flags it fixes (`build --release
# apk`, `emulators --cold`, `--device`). Commands run against a private host
# that records what they would run, so nothing here touches Ruflet::CLI.
class RufletCliUsageTest < Minitest::Test
  Commands = Ruflet::CLI::Commands

  # Every command word except help and devices: their -h/--help is not ours
  # (help lists the commands; devices forwards it to `flutter devices`).
  HELP_WORDS = %w[version -v --version create new bootstrap init run update debug build install emulators doctor].freeze
  # Commands whose flags `ruflet` reads itself, so an unknown one is a usage
  # error. build and devices pass the flags they do not read to Flutter.
  STRICT_WORDS = (HELP_WORDS - %w[build] + %w[help]).freeze

  # A copy of Ruflet::CLI whose side effects only record, and fail the test
  # when a usage error should have stopped the command first.
  class Host
    attr_reader :fetches, :ran

    def initialize
      @fetches = 0
      @ran = []
      [
        Ruflet::CLI::NewCommand,
        Ruflet::CLI::RunCommand,
        Ruflet::CLI::UpdateCommand,
        Ruflet::CLI::BuildCommand,
        Ruflet::CLI::ExtraCommand,
        Ruflet::CLI
      ].each { |mod| extend(mod) }
      define_singleton_method(:download_ruflet_assets) do |*|
        @fetches += 1
        true
      end
      define_singleton_method(:ensure_flutter!) do |*, **|
        @ran << [:ensure_flutter!]
        { flutter: "flutter", dart: "dart", env: {} }
      end
    end

    # Replaces each named method with one that records its call and returns
    # what the block returns.
    def recorder(*names, &result)
      names.each do |name|
        define_singleton_method(name) do |*args, **kwargs|
          @ran << [name, args, kwargs]
          result&.call(name, args, kwargs)
        end
      end
      self
    end
  end

  # OptionParser's own --help prints a bare switch list and calls exit; a
  # command must never end the process that way.
  def run_cli(host, argv)
    code = nil
    out, err = capture_io do
      code = host.run(argv.dup)
    rescue SystemExit => e
      code = "exit(#{e.status})"
    end
    [code, out, err]
  end

  # --- unknown flags ----------------------------------------------------------

  def test_an_unknown_flag_prints_the_commands_usage_and_exits_64_before_it_runs
    STRICT_WORDS.each do |word|
      host = Host.new
      entry = Commands.lookup(word)
      # A command with its own parser has to run to parse; it stops there.
      host.define_singleton_method(entry.handler) { |*| flunk("#{word}: the command must not run") } if entry.unknown_flags == :reject
      code, out, err = run_cli(host, [word, "--bogus-flag"])

      assert_equal 64, code, word
      assert_empty out, word
      assert_equal "ruflet #{entry.name}: invalid option: --bogus-flag\n\n#{entry.help_text}", err, word
      refute_includes err, ".rb:", "#{word}: no backtrace"
    end
  end

  def test_commands_with_their_own_parser_report_its_errors_as_usage_errors
    {
      %w[run --port] => "missing argument: --port",
      %w[run --port abc] => "invalid argument: --port abc",
      %w[run --web=1] => "needless argument: --web=1",
      %w[update --nope] => "invalid option: --nope",
      %w[debug --platform] => "missing argument: --platform",
      %w[emulators --emulator] => "missing argument: --emulator",
      %w[emulators --cold] => "--cold needs --start --emulator ID",
      %w[emulators --cold --create] => "--cold needs --start --emulator ID"
    }.each do |argv, message|
      host = Host.new
      code, out, err = run_cli(host, argv)

      assert_equal 64, code, argv.inspect
      assert_empty out, argv.inspect
      assert_equal "ruflet #{argv.first}: #{message}\n\n#{Commands.lookup(argv.first).help_text}", err, argv.inspect
      refute_includes host.ran.map(&:first), :ensure_flutter!, "#{argv.inspect}: reported before Flutter is looked up"
    end
  end

  def test_flags_that_take_a_value_need_one_and_accept_the_equals_form
    host = Host.new
    code, _out, err = run_cli(host, %w[install -d])
    assert_equal 64, code
    assert_includes err, "ruflet install: missing argument: -d"
    code, _out, err = run_cli(Host.new, %w[install --device=])
    assert_equal 64, code
    assert_includes err, "ruflet install: missing argument: --device="

    %w[--verbose=1 --fix=yes].each do |flag|
      code, _out, err = run_cli(Host.new, ["doctor", flag])
      assert_equal 64, code, flag
      assert_includes err, "ruflet doctor: needless argument: #{flag}"
    end
  end

  def test_declared_flags_and_positional_arguments_still_reach_the_command
    {
      %w[version extra] => :command_version,
      %w[new my_app] => :command_new,
      %w[create my_app] => :command_create,
      %w[install -v --device emulator-5554] => :command_install,
      %w[install --device=emulator-5554] => :command_install,
      %w[install -d emulator-5554 extra] => :command_install,
      %w[doctor --fix --verbose] => :command_doctor,
      %w[doctor -v] => :command_doctor,
      ["install", "--", "--after-the-terminator"] => :command_install,
      # A bare `-` is an argument, not a flag.
      %w[new my_app -] => :command_new
    }.each do |argv, handler|
      host = Host.new.recorder(handler) { 0 }
      code, _out, err = run_cli(host, argv)

      assert_equal 0, code, argv.inspect
      assert_empty err, argv.inspect
      assert_equal [[handler, [argv.drop(1)], {}]], host.ran, argv.inspect
    end
  end

  # build, install and doctor read their flags by exact match, so the
  # check does too: a prefix of a declared flag is not that flag.
  def test_a_prefix_of_a_declared_flag_is_an_unknown_flag
    [%w[install --dev emulator-5554], %w[install --verb], %w[doctor --fi], %w[doctor --verb]].each do |argv|
      entry = Commands.lookup(argv.first)
      host = Host.new
      host.define_singleton_method(entry.handler) { |*| flunk("#{argv.inspect}: the command must not run") }
      code, out, err = run_cli(host, argv)

      assert_equal 64, code, argv.inspect
      assert_empty out, argv.inspect
      assert_equal "ruflet #{entry.name}: invalid option: #{argv[1]}\n\n#{entry.help_text}", err, argv.inspect
    end
  end

  def test_build_and_devices_forward_flags_they_do_not_read
    [%w[build apk --bogus-flag], %w[build --bogus-flag apk], %w[devices --bogus-flag], %w[devices --help], %w[build apk --help]].each do |argv|
      handler = Commands.lookup(argv.first).handler
      host = Host.new.recorder(handler) { 0 }
      code, _out, err = run_cli(host, argv)

      assert_equal 0, code, argv.inspect
      assert_empty err, argv.inspect
      assert_equal [[handler, [argv.drop(1)], {}]], host.ran, argv.inspect
    end
  end

  # --- help -------------------------------------------------------------------

  def test_help_after_any_command_prints_its_help_and_runs_nothing
    HELP_WORDS.each do |word|
      entry = Commands.lookup(word)
      [["--help"], ["-h"], ["extra", "-h"], ["--web", "--help", "--bogus-flag"]].each do |args|
        next if word == "build" && args.first == "extra" # build's first positional is the target

        host = Host.new
        host.define_singleton_method(entry.handler) { |*| flunk("#{word}: the command must not run") }
        code, out, err = run_cli(host, [word, *args])

        assert_equal 0, code, [word, *args].inspect
        assert_equal entry.help_text, out, [word, *args].inspect
        assert_empty err, [word, *args].inspect
        assert_equal 0, host.fetches, "#{word}: help fetches nothing"
      end
    end
  end

  # `--` ends the options: a help flag after it is an argument for the
  # command (`run main.rb -- --help` runs main.rb).
  def test_a_help_flag_after_the_end_of_options_reaches_the_command
    [%w[run main.rb -- --help], %w[install -- -h], %w[update -- --help]].each do |argv|
      handler = Commands.lookup(argv.first).handler
      host = Host.new.recorder(handler) { 0 }
      code, out, err = run_cli(host, argv)

      assert_equal 0, code, argv.inspect
      assert_empty out, argv.inspect
      assert_empty err, argv.inspect
      assert_equal [[handler, [argv.drop(1)], {}]], host.ran, argv.inspect
    end
  end

  def test_build_help_comes_from_flutter_after_the_target
    host = Host.new.recorder(:command_build) { 0 }
    code, out, = run_cli(host, %w[build --release --help])
    assert_equal 0, code
    assert_equal Commands.lookup("build").help_text, out
    assert_empty host.ran

    code, = run_cli(host, %w[build ios --help])
    assert_equal 0, code
    assert_equal [[:command_build, [%w[ios --help]], {}]], host.ran
  end

  def test_an_abbreviated_help_flag_reaches_the_commands_own_parser
    %w[run update debug emulators].each do |word|
      host = Host.new
      code, out, err = run_cli(host, [word, "--hel"])

      assert_equal 0, code, word
      assert_equal Commands.lookup(word).help_text, out, word
      assert_empty err, word
    end
  end

  def test_help_names_a_command
    Commands.words.each do |word|
      entry = Commands.lookup(word)
      next if entry.name == "help"

      [word, word.upcase].each do |spelling|
        host = Host.new
        code, out, err = run_cli(host, ["help", spelling])

        assert_equal 0, code, spelling
        assert_equal entry.help_text, out, spelling
        assert_empty err, spelling
      end
    end
  end

  def test_help_without_a_command_word_still_lists_every_command
    [
      %w[help], %w[help help], %w[help -h], %w[help --help], %w[help bogus], %w[--help bogus], %w[-h],
      # `--` ends the options; it is not a bad flag, and nothing after it is read.
      %w[help --], %w[--help --], %w[help -- build],
      # A bare `-` is not a flag either.
      %w[help -]
    ].each do |argv|
      code, out, err = run_cli(Host.new, argv)

      assert_equal 0, code, argv.inspect
      assert_equal Commands.help_text, out, argv.inspect
      assert_empty err, argv.inspect
    end
  end

  def test_a_bare_dash_is_not_a_flag
    refute Commands.flag?("-")
    %w[-x --x --x=1 --].each { |arg| assert Commands.flag?(arg), arg }
  end

  def test_build_help_text
    assert_equal <<~HELP, Commands.lookup("build").help_text
      Usage: ruflet build <apk|android|ios|ipa|aab|web|macos|windows|linux> [--lite|--full|--self] [--verbose]

      Build the app for one platform. The target may come before or after the flags.

      Options:
        --self           Self-contained lite build (default profile)
        --lite           Self-contained lite build
        --full           Self-contained full CRuby build with locked project gems
        -v, --verbose    Print each step and run Flutter with -v
        --strict         Fail when the template lacks a control, service or extension the app uses
        -h, --help       Show this help

      Other arguments are passed to `flutter build <target>`.

      Build profiles:
        --self           Self-contained lite build (default profile)
        --self --full    Self-contained full CRuby build with locked project gems
        --full           Also implies --self
    HELP
  end

  def test_every_command_help_lists_its_usage_and_options
    Commands.commands.each do |entry|
      text = entry.help_text

      assert text.start_with?("Usage: ruflet "), entry.name
      entry.options.each { |option| assert_includes text, "  #{option.label} ", "#{entry.name}: #{option.label}" }
      option_lines = text.lines.grep(/\A  -/).join
      entry.options.flat_map(&:hidden).each do |hidden|
        refute_match(/(?<![\w-])#{Regexp.escape(hidden)}(?![\w-])/, option_lines, "#{entry.name}: #{hidden} is not listed")
      end
      assert_includes text, "`#{entry.forwards}`", entry.name if entry.forwards
    end
    assert_equal %w[--de --d], Commands.lookup("run").options.flat_map(&:hidden)
    assert_equal %w[-c --c], Commands.lookup("emulators").options.flat_map(&:hidden)
    assert_includes Commands.lookup("debug").help_text, "Usage: ruflet debug [platform] "
    assert_match(/^  --device-id ID, --device ID +Flutter device to run on$/, Commands.lookup("debug").help_text)
    assert_includes Commands.lookup("new").help_text, "Aliases: bootstrap, init"
  end

  # --- run: -d stays --desktop; --device is reserved ---------------------------

  def run_target(argv)
    host = Host.new
    options = host.send(:parse_run_options, argv.dup)
    [options[:target], options[:device]]
  end

  def test_run_desktop_keeps_every_spelling_it_had
    [%w[-d], %w[--d], %w[--de], %w[--des], %w[--desktop], %w[main.rb -d], %w[-d main.rb]].each do |argv|
      assert_equal ["desktop", nil], run_target(argv), argv.inspect
    end
    assert_equal ["web", nil], run_target(%w[-w])
    assert_equal ["mobile", nil], run_target(%w[main.rb])
  end

  def test_run_device_takes_a_long_flag_only
    [%w[--device emulator-5554], %w[--device=emulator-5554], %w[--dev emulator-5554]].each do |argv|
      assert_equal ["mobile", "emulator-5554"], run_target(argv), argv.inspect
    end
  end

  def test_run_device_says_it_is_not_supported_yet_and_starts_nothing
    host = Host.new
    host.define_singleton_method(:resolve_backend_port) { |*, **| flunk("no server starts") }
    code = nil
    out, err = capture_io { code = host.command_run(%w[main.rb --device emulator-5554]) }

    assert_equal 1, code
    assert_empty out
    assert_includes err, "ruflet run: --device is not supported yet."
    assert_includes err, "`ruflet install --device emulator-5554`"
  end

  # --- debug: --device is the long name of --device-id -------------------------

  def test_debug_device_spellings_select_the_same_flutter_device
    [%w[--device chrome], %w[--device=chrome], %w[--device-id chrome], %w[-d chrome], %w[--dev chrome]].each do |argv|
      host = Host.new
      ran = nil
      host.define_singleton_method(:detect_client_dir) { "/client" }
      host.define_singleton_method(:system) do |*cmd, **options|
        ran = [cmd, options]
        true
      end
      system("true")
      capture_io { host.command_debug(argv.dup) }

      assert_equal [[{}, "flutter", "run", "-d", "chrome"], { chdir: "/client" }], ran, argv.inspect
    end
  end

  # --- emulators --cold ----------------------------------------------------------

  def test_emulators_cold_boots_the_started_emulator
    host = Host.new
    ran = nil
    host.define_singleton_method(:system) do |*cmd|
      ran = cmd
      true
    end
    system("true")
    code = nil
    capture_io { code = host.command_emulators(%w[--start --emulator Pixel_8_API_35 --cold -v]) }

    assert_equal 0, code
    assert_equal [{}, "flutter", "emulators", "--launch", "Pixel_8_API_35", "--cold", "-v"], ran
  end

  def test_the_abbreviations_of_create_still_reach_it_beside_cold
    [%w[-c], %w[--c], %w[--cr], %w[--create]].each do |argv|
      code, out, err = run_cli(Host.new, ["emulators", *argv])

      assert_equal 1, code, argv.inspect
      assert_empty out, argv.inspect
      assert_equal "ruflet emulators --create is not implemented yet. Use your platform tools.\n", err, argv.inspect
    end
    code, _out, err = run_cli(Host.new, %w[emulators --co])
    assert_equal 64, code
    assert err.start_with?("ruflet emulators: --cold needs --start --emulator ID\n\n"), err
  end

  # --- build: the target may follow flags ---------------------------------------

  def test_the_build_target_is_the_first_argument_or_the_one_argument_naming_a_target
    host = Host.new
    {
      %w[apk --release] => ["apk", %w[--release]],
      %w[APK] => ["apk", []],
      %w[bogus --release] => ["bogus", %w[--release]],
      [] => ["", []],
      %w[--release apk] => ["apk", %w[--release]],
      %w[--release --split-per-abi aab] => ["aab", %w[--release --split-per-abi]],
      %w[--target-platform android-arm64 apk --release] => ["apk", %w[--target-platform android-arm64 --release]],
      %w[--build-name 1.2.3 IOS] => ["ios", %w[--build-name 1.2.3]],
      %w[--flavor prod] => ["prod", %w[--flavor]],
      %w[--release] => ["", %w[--release]],
      # Nothing after `--` names the target.
      %w[-- apk] => ["--", %w[apk]],
      %w[--release -- apk] => ["", %w[--release -- apk]],
      %w[--release apk -- web] => ["apk", %w[--release -- web]],
      %w[apk -- --release] => ["apk", %w[-- --release]],
      # A bare `-` is an argument, as Commands.flag? has it.
      %w[- apk] => ["-", %w[apk]],
      %w[--release - apk] => ["apk", %w[--release -]],
      %w[--release -] => ["-", %w[--release]]
    }.each do |argv, (target, rest)|
      args = argv.dup
      assert_equal target, host.send(:extract_build_target!, args), argv.inspect
      assert_equal rest, args, argv.inspect
    end
  end

  def test_two_arguments_naming_a_target_after_a_flag_are_refused
    host = Host.new
    error = assert_raises(Ruflet::CLI::Commands::UsageError) { host.send(:extract_build_target!, %w[--flavor web apk]) }
    assert_equal "more than one argument names a build target (web, apk); put the target first", error.message

    code, _out, err = run_cli(Host.new.recorder(:ensure_ruflet_build_assets) { flunk("nothing is prepared") }, %w[build --flavor web apk])
    assert_equal 64, code
    assert err.start_with?("ruflet build: more than one argument names a build target (web, apk); put the target first\n\nUsage: ruflet build ")
  end

  def test_build_end_of_options_first_is_still_an_unsupported_target
    host = Host.new.recorder(:ensure_ruflet_build_assets) { flunk("nothing is prepared") }
    code, out, err = run_cli(host, %w[build -- apk])

    assert_equal 1, code
    assert_empty out
    assert_equal "Unsupported build target: --\n", err
  end

  def test_a_bare_dash_first_is_still_an_unsupported_target
    host = Host.new.recorder(:ensure_ruflet_build_assets) { flunk("nothing is prepared") }
    code, out, err = run_cli(host, %w[build --self - apk])

    assert_equal 1, code
    assert_empty out
    assert_equal "Unsupported build target: -\n", err
  end

  # The H1 goldens of both spellings, minus the line naming the invocation.
  def test_release_before_the_target_reaches_flutter_like_release_after_it
    strip = ->(text) { text.lines.reject { |line| line.start_with?("command: ") }.join }
    %w[default_app services_app].each do |fixture|
      goldens = File.expand_path("compat/goldens/cli/#{fixture}", __dir__)
      before = File.read(File.join(goldens, "build--release-apk.txt"))
      after = File.read(File.join(goldens, "build-apk--release.txt"))

      assert_equal strip.call(after), strip.call(before), fixture
    end
    services = File.read(File.expand_path("compat/goldens/cli/services_app/build--release-apk.txt", __dir__))
    assert_includes services, "/bin/flutter build apk --release --target lib/main.server.dart"
  end

  # --- handlers called directly ------------------------------------------------------

  # ruflet_rails' rake tasks call the handlers themselves (`rake
  # ruflet:update[--help]` is `Ruflet::CLI.command_update(["--help"])`), with
  # no Ruflet::CLI.run around them; so does this host.
  def call_handler(handler, argv)
    host = Object.new
    [
      Ruflet::CLI::NewCommand,
      Ruflet::CLI::RunCommand,
      Ruflet::CLI::UpdateCommand,
      Ruflet::CLI::BuildCommand,
      Ruflet::CLI::ExtraCommand
    ].each { |mod| host.extend(mod) }
    code = nil
    out, err = capture_io do
      code = host.public_send(handler, argv.dup)
    rescue SystemExit => e
      code = "exit(#{e.status})"
    end
    [code, out, err]
  end

  def test_a_handler_called_directly_prints_its_help
    {
      %w[update --help] => :command_update,
      %w[update -h] => :command_update,
      %w[update --he] => :command_update,
      %w[update web --help] => :command_update,
      %w[run -h] => :command_run,
      %w[run main.rb --help] => :command_run,
      %w[debug --help] => :command_debug,
      %w[debug web -h] => :command_debug,
      %w[emulators -h] => :command_emulators,
      %w[emulators --start --help] => :command_emulators
    }.each do |argv, handler|
      code, out, err = call_handler(handler, argv.drop(1))

      assert_equal 0, code, argv.inspect
      assert_equal Commands.lookup(argv.first).help_text, out, argv.inspect
      assert_empty err, argv.inspect
    end
  end

  def test_a_handler_called_directly_reports_its_usage_errors
    {
      %w[build --flavor web apk] => "more than one argument names a build target (web, apk); put the target first",
      %w[emulators --cold] => "--cold needs --start --emulator ID"
    }.each do |argv, reason|
      entry = Commands.lookup(argv.first)
      code, out, err = call_handler(entry.handler, argv.drop(1))

      assert_equal 64, code, argv.inspect
      assert_empty out, argv.inspect
      assert_equal "ruflet #{entry.name}: #{reason}\n\n#{entry.help_text}", err, argv.inspect
    end
  end

  # A flag the handler's own parser rejects still raises OptionParser's
  # error to a direct caller, as before CLI-12; only Ruflet::CLI.run turns
  # it into a usage error.
  def test_a_handler_called_directly_still_raises_its_parsers_errors
    error = assert_raises(OptionParser::InvalidOption) { call_handler(:command_update, %w[--bogus-flag]) }
    assert_equal "invalid option: --bogus-flag", error.message
  end

  # --- install --device=ID ---------------------------------------------------------

  def test_install_reads_the_device_in_either_form
    [%w[--device emulator-5554], %w[--device=emulator-5554], %w[-d emulator-5554]].each do |argv|
      host = Host.new
      seen = nil
      host.define_singleton_method(:ensure_flutter_client_dir) { |**| "/client" }
      host.define_singleton_method(:install_tool_env) { |env, _client_dir| env }
      host.define_singleton_method(:install_platform_for_device) do |device_id|
        seen = device_id
        throw :installed
      end
      catch(:installed) { capture_io { host.command_install(argv.dup) } }

      assert_equal "emulator-5554", seen, argv.inspect
    end
  end
end
