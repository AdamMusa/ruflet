# frozen_string_literal: true

require_relative "test_helper"

# Ruflet::CLI.run: every command name and alias reaches its handler, the
# first-run template download happens only for the commands that need it,
# and usage errors exit 1 instead of raising.
class RufletCliDispatchTest < Minitest::Test
  ROUTES = {
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

  # Only these fetch the Flutter template before running (cli.rb).
  DOWNLOADING = %w[create new bootstrap init update debug build install doctor].freeze

  def test_each_command_and_alias_reaches_its_handler_with_the_remaining_args
    ROUTES.each do |command, handler|
      received = nil
      code = with_assets_stubbed do
        Ruflet::CLI.stub(handler, ->(args) { received = args; 7 }) do
          Ruflet::CLI.run([command, "--flag", "value"])
        end
      end

      assert_equal 7, code, "#{command} must return its handler's exit code"
      assert_equal ["--flag", "value"], received, "#{command} -> #{handler}"
    end
  end

  def test_command_names_are_case_insensitive
    received = nil
    with_assets_stubbed do
      Ruflet::CLI.stub(:command_build, ->(args) { received = args; 0 }) do
        assert_equal 0, Ruflet::CLI.run(["BUILD", "apk"])
      end
    end
    assert_equal ["apk"], received
  end

  def test_first_run_assets_are_fetched_only_for_commands_that_need_the_template
    ROUTES.each do |command, handler|
      downloads = 0
      with_assets_stubbed(-> { downloads += 1 }) do
        Ruflet::CLI.stub(handler, ->(_args) { 0 }) { Ruflet::CLI.run([command]) }
      end

      expected = DOWNLOADING.include?(command) ? 1 : 0
      assert_equal expected, downloads, "first-run download for #{command}"
    end

    downloads = 0
    capture_io do
      with_assets_stubbed(-> { downloads += 1 }) do
        Ruflet::CLI.run(["--version"])
        Ruflet::CLI.run(["help"])
      end
    end
    assert_equal 0, downloads
  end

  def test_a_failed_first_run_download_does_not_stop_the_command
    ran = false
    with_assets_stubbed(-> { raise SocketError, "offline" }) do
      Ruflet::CLI.stub(:command_doctor, ->(_args) { ran = true; 0 }) do
        assert_equal 0, Ruflet::CLI.run(["doctor"])
      end
    end
    assert ran
  end

  def test_version_aliases
    %w[version -v --version VERSION].each do |alias_name|
      out, = capture_io { assert_equal 0, Ruflet::CLI.run([alias_name]) }
      assert_equal "ruflet #{Ruflet::VERSION}\n", out, alias_name
    end
  end

  def test_help_aliases_and_no_arguments_print_help
    [["help"], ["-h"], ["--help"], []].each do |argv|
      out, = capture_io { assert_equal 0, Ruflet::CLI.run(argv.dup) }
      assert_includes out, "Ruflet CLI", argv.inspect
    end
  end

  def test_unknown_options_are_usage_errors_not_crashes
    cases = {
      %w[run --bogus] => "invalid option: --bogus",
      %w[run --port abc] => "invalid argument: --port abc",
      %w[update --platform] => "missing argument: --platform",
      %w[debug --bogus] => "invalid option: --bogus",
      %w[emulators --bogus] => "invalid option: --bogus"
    }

    cases.each do |argv, message|
      Ruflet::CLI.stub(:ensure_flutter!, ->(*) { flunk "#{argv.inspect} must fail before touching Flutter" }) do
        _out, err = capture_io do
          with_assets_stubbed { assert_equal 1, Ruflet::CLI.run(argv.dup), argv.inspect }
        end
        assert_includes err, "ruflet #{argv.first}: #{message}"
        assert_includes err, "ruflet help"
      end
    end
  end

  def test_help_documents_what_the_parsers_accept
    out, = capture_io { Ruflet::CLI.print_help }

    # debug's positional is a platform (extra_command.rb); it used to be
    # documented as a script.
    refute_includes out, "ruflet debug [scriptname"
    assert_includes out, "ruflet debug [web|macos|windows|linux|ios|android]"
    %w[--platform --device-id --release --web-renderer].each { |flag| assert_includes out, flag }
    assert_includes out, "appbundle"
    assert_includes out, "--device|-d DEVICE_ID"
    assert_includes out, "ruflet emulators [--start --emulator ID]"
    assert_includes out, "[web|desktop|all|check]"
    assert_includes out, "(also: bootstrap, init)"
    assert_includes out, "(also: version, -v)"
    assert_includes out, "(also: -h, --help)"
    # The default build is server-driven, not --self.
    refute_includes out, "(default profile)"
  end

  def test_bootstrap_returns_the_scaffold_status
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        capture_io do
          assert_equal 0, Ruflet::CLI.bootstrap("demo")
          # It used to return 0 here too, after printing that the directory exists.
          assert_equal 1, Ruflet::CLI.bootstrap("demo")
        end
        assert File.file?(File.join(dir, "demo", "main.rb"))
      end
    end
  end

  private

  def with_assets_stubbed(callback = -> {}, &block)
    Ruflet::CLI.stub(:download_ruflet_assets, ->(*) { callback.call }, &block)
  end
end
