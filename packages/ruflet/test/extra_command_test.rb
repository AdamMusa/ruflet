# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "rbconfig"

class RufletCliExtraCommandTest < Minitest::Test
  class DummyExtra
    include Ruflet::CLI::ExtraCommand
  end

  def test_doctor_without_fix_reports_missing_flutter_without_installing
    runner = DummyExtra.new
    runner.define_singleton_method(:detect_client_dir) { nil }
    runner.define_singleton_method(:resolve_ruflet_client_template_root) { nil }
    runner.define_singleton_method(:flutter_host) { "macos_arm64" }
    runner.define_singleton_method(:flutter_tools) { |client_dir: nil, auto_install: true| auto_install ? { flutter: "unexpected", env: {} } : nil }

    err = StringIO.new
    out = StringIO.new
    original_stderr = $stderr
    original_stdout = $stdout
    $stderr = err
    $stdout = out

    code = runner.command_doctor([])

    assert_equal 1, code
    assert_includes out.string, "Flutter host target: macos_arm64"
    assert_includes err.string, "Template: missing"
    assert_includes err.string, "Run `ruflet doctor --fix`"
  ensure
    $stderr = original_stderr
    $stdout = original_stdout
  end

  def test_doctor_without_fix_reports_the_flutter_sdk_doctor_fix_installed
    Dir.mktmpdir do |home|
      bin_dir = File.join(home, ".ruflet", "flutter", "3.41.2", "macos_arm64", "flutter", "bin")
      FileUtils.mkdir_p(bin_dir)
      flutter = File.join(bin_dir, "flutter")
      File.write(flutter, "#!/bin/sh\necho '{\"frameworkVersion\":\"3.41.2\",\"channel\":\"stable\"}'\n")
      FileUtils.chmod("+x", flutter)

      runner = DummyExtra.new
      flutter_runs = []
      runner.define_singleton_method(:detect_client_dir) { nil }
      runner.define_singleton_method(:resolve_ruflet_client_template_root) { "/tmp/ruflet_flutter_template" }
      runner.define_singleton_method(:flutter_host) { "macos_arm64" }
      runner.define_singleton_method(:windows_host?) { false }
      runner.define_singleton_method(:which_command) { |_name| nil }
      runner.define_singleton_method(:desired_flutter_spec) { |client_dir: nil| { channel: "stable", source: :metadata } }
      runner.define_singleton_method(:fetch_releases_manifest) { |_host| raise Minitest::Assertion, "plain doctor must not fetch the release manifest" }
      runner.define_singleton_method(:download_file) { |url, _destination| raise Minitest::Assertion, "plain doctor must not download #{url}" }
      runner.define_singleton_method(:system) { |_env, *args| flutter_runs << args; true }

      err = StringIO.new
      out = StringIO.new
      original_stderr = $stderr
      original_stdout = $stdout
      original_home = Dir.method(:home)
      Dir.define_singleton_method(:home) { home }
      $stderr = err
      $stdout = out

      code = runner.command_doctor([])

      assert_equal 0, code
      assert_includes out.string, "Flutter: 3.41.2 stable"
      refute_includes err.string, "Flutter: missing"
      assert_equal [[flutter, "doctor"]], flutter_runs
    ensure
      $stderr = original_stderr
      $stdout = original_stdout
      Dir.define_singleton_method(:home, original_home) if original_home
    end
  end

  def test_doctor_fix_uses_host_platform_install_path
    runner = DummyExtra.new
    calls = []
    runner.define_singleton_method(:detect_client_dir) { "/tmp/client" }
    runner.define_singleton_method(:resolve_ruflet_client_template_root) { nil }
    runner.define_singleton_method(:ensure_cached_ruflet_client_template!) { |force: false, verbose: false| "/tmp/ruflet_flutter_template" }
    runner.define_singleton_method(:flutter_host) { "macos_arm64" }
    runner.define_singleton_method(:ensure_flutter!) do |command_name, client_dir: nil, auto_install: true|
      calls << { command_name: command_name, client_dir: client_dir, auto_install: auto_install }
      { flutter: "/tmp/client/.fvm/flutter_sdk/bin/flutter", env: {} }
    end
    runner.define_singleton_method(:flutter_version_summary) { |_tools| "3.41.4 stable" }
    runner.define_singleton_method(:system) { |_env, *_args| true }

    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = runner.command_doctor(["--fix"])

    assert_equal 0, code
    assert_equal [{ command_name: "doctor", client_dir: "/tmp/client", auto_install: true }], calls
    assert_includes out.string, "Flutter host target: macos_arm64"
    assert_includes out.string, "Template: /tmp/ruflet_flutter_template"
    assert_includes out.string, "Ruby runtime: pub.dev package"
    assert_includes out.string, "Flutter: 3.41.4 stable"
    refute_includes out.string, "/tmp/client/.fvm/flutter_sdk/bin/flutter"
  ensure
    $stdout = original_stdout
  end

  # command_doctor/devices/emulators/debug used to return $?.exitstatus. $? is
  # per thread and still describes the previous child, so a stubbed or
  # non-spawning system reported someone else's status: this suite's
  # test_doctor_fix_uses_host_platform_install_path failed by seed whenever an
  # earlier test in the process left a failing $?.
  def test_exit_codes_follow_system_not_a_stale_last_status
    runner = doctor_runner(system_result: true)
    leave_last_status(4)
    capture_io { assert_equal 0, runner.command_doctor(["--fix"]) }

    runner = flutter_runner
    runner.define_singleton_method(:system) { |*_args, **_opts| true }
    leave_last_status(4)
    assert_equal 0, runner.command_devices([])
    leave_last_status(4)
    assert_equal 0, runner.command_emulators([])
    leave_last_status(4)
    with_client_dir { |dir| assert_equal 0, debug_runner(dir).command_debug([]) }
  end

  # The other way round: a system call that failed (false or nil) while $?
  # still describes an earlier child that succeeded must not report 0.
  def test_a_failed_system_call_never_reports_a_stale_success
    [false, nil].each do |result|
      runner = doctor_runner(system_result: result)
      leave_last_status(0)
      capture_io { assert_equal 1, runner.command_doctor(["--fix"]), "doctor, system => #{result.inspect}" }

      runner = flutter_runner
      runner.define_singleton_method(:system) { |*_args, **_opts| result }
      leave_last_status(0)
      assert_equal 1, runner.command_devices([]), "devices, system => #{result.inspect}"
      leave_last_status(0)
      assert_equal 1, runner.command_emulators([]), "emulators, system => #{result.inspect}"
      leave_last_status(0)
      with_client_dir do |dir|
        runner = debug_runner(dir)
        runner.define_singleton_method(:system) { |*_args, **_opts| result }
        assert_equal 1, runner.command_debug([]), "debug, system => #{result.inspect}"
      end
    end
  end

  def test_failing_flutter_status_is_passed_through
    runner = doctor_runner(system_result: :exit_3)
    capture_io { assert_equal 3, runner.command_doctor(["--fix"]) }

    runner = flutter_runner
    runner.define_singleton_method(:system) { |*_args, **_opts| Kernel.system(RbConfig.ruby, "-e", "exit 2") }
    assert_equal 2, runner.command_devices(["--machine"])
  end

  def test_doctor_verbose_flags_pass_v_to_flutter_doctor
    ["--verbose", "-v"].each do |flag|
      runner = doctor_runner(system_result: true)
      capture_io { runner.command_doctor(["--fix", flag]) }
      assert_equal ["flutter", "doctor", "-v"], runner.instance_variable_get(:@flutter_calls).last, flag
    end

    runner = doctor_runner(system_result: true)
    capture_io { runner.command_doctor(["--fix"]) }
    assert_equal ["flutter", "doctor"], runner.instance_variable_get(:@flutter_calls).last
  end

  def test_doctor_without_fix_reports_a_healthy_setup
    runner = doctor_runner(system_result: true)
    runner.define_singleton_method(:resolve_ruflet_client_template_root) { "/tmp/template" }
    runner.define_singleton_method(:flutter_tools) { |client_dir: nil, auto_install: true| auto_install ? flunk("doctor must not install") : { flutter: "flutter", env: {} } }

    out, err = capture_io { assert_equal 0, runner.command_doctor([]) }
    assert_includes out, "Template: /tmp/template"
    assert_includes out, "Flutter: 3.41.4 stable"
    assert_empty err
  end

  def test_doctor_fix_fails_when_the_template_cannot_be_fetched
    runner = doctor_runner(system_result: true)
    runner.define_singleton_method(:ensure_cached_ruflet_client_template!) { |force: false, verbose: false| nil }
    runner.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| flunk("no Flutter install without a template") }

    _out, err = capture_io { assert_equal 1, runner.command_doctor(["--fix"]) }
    assert_includes err, "Failed to fetch the Ruflet Flutter template from GitHub."
  end

  def test_devices_passes_its_arguments_to_flutter_devices
    runner = flutter_runner
    calls = record_system(runner)
    assert_equal 0, runner.command_devices(["--machine", "--device-timeout", "5"])
    assert_equal [["flutter", "devices", "--machine", "--device-timeout", "5"]], calls
  end

  def test_emulators_list_start_and_verbose
    {
      [] => ["flutter", "emulators"],
      ["-v"] => ["flutter", "emulators", "-v"],
      ["--verbose"] => ["flutter", "emulators", "-v"],
      ["--start", "--emulator", "pixel_7"] => ["flutter", "emulators", "--launch", "pixel_7"],
      ["--start", "--emulator", "pixel_7", "-v"] => ["flutter", "emulators", "--launch", "pixel_7", "-v"]
    }.each do |argv, expected|
      runner = flutter_runner
      calls = record_system(runner)
      assert_equal 0, runner.command_emulators(argv.dup), argv.inspect
      assert_equal [expected], calls, argv.inspect
    end
  end

  # These answer without Flutter; ensure_flutter! may install an SDK or exit.
  def test_emulators_usage_errors_do_not_touch_flutter
    {
      ["--start"] => "Missing --emulator for start",
      ["--create"] => "ruflet emulators --create is not implemented yet",
      ["--delete"] => "ruflet emulators --delete is not implemented yet"
    }.each do |argv, message|
      runner = DummyExtra.new
      runner.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| flunk("#{argv.inspect} must not need Flutter") }
      _out, err = capture_io { assert_equal 1, runner.command_emulators(argv.dup), argv.inspect }
      assert_includes err, message
    end
  end

  def test_debug_maps_platforms_and_options_to_flutter_run
    {
      [] => ["flutter", "run"],
      ["web"] => ["flutter", "run", "-d", "chrome"],
      ["--platform", "web"] => ["flutter", "run", "-d", "chrome"],
      ["macos"] => ["flutter", "run", "-d", "macos"],
      ["--platform", "linux"] => ["flutter", "run", "-d", "linux"],
      ["windows"] => ["flutter", "run", "-d", "windows"],
      ["ios"] => ["flutter", "run"],
      ["android"] => ["flutter", "run"],
      ["web", "--device-id", "emulator-5554"] => ["flutter", "run", "-d", "emulator-5554"],
      ["--release", "-v", "--web-renderer", "canvaskit", "web"] =>
        ["flutter", "run", "--release", "-v", "--web-renderer", "canvaskit", "-d", "chrome"],
      ["--verbose"] => ["flutter", "run", "-v"]
    }.each do |argv, expected|
      with_client_dir do |dir|
        runner = debug_runner(dir)
        calls = record_system(runner, with_chdir: true)
        assert_equal 0, runner.command_debug(argv.dup), argv.inspect
        assert_equal [[expected, dir]], calls, argv.inspect
      end
    end
  end

  def test_debug_without_a_client_explains_and_fails
    runner = DummyExtra.new
    runner.define_singleton_method(:detect_client_dir) { nil }
    runner.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| flunk("no client, no Flutter") }

    _out, err = capture_io { assert_equal 1, runner.command_debug(["web"]) }
    assert_includes err, "Could not find Flutter client directory."
    assert_includes err, "ruflet run --web"
  end

  def test_debug_passes_through_flutter_run_failures
    with_client_dir do |dir|
      runner = debug_runner(dir)
      runner.define_singleton_method(:system) { |*_args, **_opts| Kernel.system(RbConfig.ruby, "-e", "exit 5") }
      assert_equal 5, runner.command_debug(["web"])
    end
  end

  def test_detect_client_dir_prefers_ruflet_client_dir_then_build_client
    with_client_dir do |dir|
      runner = DummyExtra.new
      previous = ENV["RUFLET_CLIENT_DIR"]
      ENV["RUFLET_CLIENT_DIR"] = dir
      assert_equal dir, runner.send(:detect_client_dir)

      ENV["RUFLET_CLIENT_DIR"] = File.join(dir, "missing")
      Dir.mktmpdir do |project|
        Dir.chdir(project) do
          assert_nil runner.send(:detect_client_dir)
          FileUtils.mkdir_p(File.join(project, "build", "client"))
          assert_equal File.realpath(File.join(project, "build", "client")), File.realpath(runner.send(:detect_client_dir))
        end
      end
    ensure
      ENV["RUFLET_CLIENT_DIR"] = previous
    end
  end

  private

  def doctor_runner(system_result:)
    runner = DummyExtra.new
    flutter_calls = []
    runner.instance_variable_set(:@flutter_calls, flutter_calls)
    runner.define_singleton_method(:detect_client_dir) { "/tmp/client" }
    runner.define_singleton_method(:resolve_ruflet_client_template_root) { nil }
    runner.define_singleton_method(:ensure_cached_ruflet_client_template!) { |force: false, verbose: false| "/tmp/template" }
    runner.define_singleton_method(:flutter_host) { "macos_arm64" }
    runner.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| { flutter: "flutter", env: {} } }
    runner.define_singleton_method(:flutter_version_summary) { |_tools| "3.41.4 stable" }
    runner.define_singleton_method(:system) do |_env, *args, **_opts|
      flutter_calls << args
      system_result == :exit_3 ? Kernel.system(RbConfig.ruby, "-e", "exit 3") : system_result
    end
    runner
  end

  def flutter_runner
    runner = DummyExtra.new
    runner.define_singleton_method(:ensure_flutter!) { |*_args, **_opts| { flutter: "flutter", env: {} } }
    runner
  end

  def debug_runner(client_dir)
    runner = flutter_runner
    runner.define_singleton_method(:detect_client_dir) { client_dir }
    runner.define_singleton_method(:system) { |*_args, **_opts| true }
    runner
  end

  def record_system(runner, with_chdir: false)
    calls = []
    runner.define_singleton_method(:system) do |_env, *args, chdir: nil, **_opts|
      calls << (with_chdir ? [args, chdir] : args)
      true
    end
    calls
  end

  def with_client_dir
    Dir.mktmpdir { |dir| yield dir }
  end

  # Leaves $? describing a child that exited with code (0 included).
  def leave_last_status(code)
    Kernel.system(RbConfig.ruby, "-e", "exit #{code}")
    assert_equal code, $?.exitstatus
  end
end
