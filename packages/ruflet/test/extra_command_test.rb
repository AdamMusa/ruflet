# frozen_string_literal: true

require_relative "test_helper"

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

  def test_doctor_fix_uses_host_platform_install_path
    runner = DummyExtra.new
    calls = []
    runner.define_singleton_method(:detect_client_dir) { "/tmp/client" }
    runner.define_singleton_method(:resolve_ruflet_client_template_root) { nil }
    runner.define_singleton_method(:ensure_cached_ruflet_client_template!) { |verbose: false| "/tmp/ruflet_flutter_template" }
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
    assert_includes out.string, "Flutter: 3.41.4 stable"
    refute_includes out.string, "/tmp/client/.fvm/flutter_sdk/bin/flutter"
  ensure
    $stdout = original_stdout
  end
end
