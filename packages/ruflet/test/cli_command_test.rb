# frozen_string_literal: true

require_relative "test_helper"

class RufletCliCommandTest < Minitest::Test
  def test_print_help_excludes_pack_and_publish
    out = StringIO.new
    original_stdout = $stdout
    $stdout = out
    Ruflet::CLI.print_help
    help = out.string

    refute_includes help, "ruflet pack"
    refute_includes help, "ruflet publish"
    assert_includes help, "ruflet build"
    assert_includes help, "ruflet update"
  ensure
    $stdout = original_stdout
  end

  def test_removed_pack_command_returns_unknown
    err = StringIO.new
    out = StringIO.new
    original_stderr = $stderr
    original_stdout = $stdout
    $stderr = err
    $stdout = out

    code = Ruflet::CLI.run(["pack"])
    assert_equal 1, code
    assert_includes err.string, "Unknown command: pack"
  ensure
    $stderr = original_stderr
    $stdout = original_stdout
  end

  def test_version_command_prints_version
    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = Ruflet::CLI.run(["--version"])

    assert_equal 0, code
    assert_equal "ruflet #{Ruflet::VERSION}\n", out.string
  ensure
    $stdout = original_stdout
  end
end
