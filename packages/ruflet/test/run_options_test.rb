# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

# `ruflet run` options and the environment command_run hands the app, driven
# up to the point where it would spawn the child (build_runtime_command is
# stubbed to capture its arguments and stop there).
class RufletCliRunOptionsTest < Minitest::Test
  class DummyRunner
    include Ruflet::CLI::RunCommand
  end

  def test_option_parsing
    {
      [] => { target: "mobile", requested_port: 8550, reload: true },
      ["--web"] => { target: "web", requested_port: 8550, reload: true },
      ["--desktop"] => { target: "desktop", requested_port: 8550, reload: true },
      ["--port", "9100"] => { target: "mobile", requested_port: 9100, reload: true },
      ["--no-reload"] => { target: "mobile", requested_port: 8550, reload: false },
      ["app.rb", "--desktop", "--port", "9200", "--no-reload"] => { target: "desktop", requested_port: 9200, reload: false }
    }.each do |argv, expected|
      assert_equal expected, DummyRunner.new.send(:parse_run_options, argv.dup), argv.inspect
    end
  end

  def test_a_missing_script_fails_with_the_paths_it_tried
    in_project do
      _out, err = capture_io { assert_equal 1, spawnless_runner.command_run(["nope"]) }
      assert_includes err, "Script not found: nope"
      assert_includes err, "Expected: ./nope.rb, ./nope, or explicit file path."
    end
  end

  def test_script_resolution_defaults_to_main_and_adds_rb
    in_project do |dir|
      File.write("main.rb", "")
      File.write("other.rb", "")
      FileUtils.mkdir_p("sub")
      File.write(File.join("sub", "app"), "")

      { [] => "main.rb", ["other"] => "other.rb", ["other.rb"] => "other.rb", ["sub/app"] => "sub/app" }.each do |argv, file|
        runner = spawnless_runner
        capture_io { runner.command_run(argv.dup) }
        assert_equal File.realpath(File.join(dir, file)), File.realpath(runner.calls[:script]), argv.inspect
      end
    end
  end

  def test_the_child_environment_carries_target_port_and_assets
    in_project do |dir|
      File.write("main.rb", "")
      FileUtils.mkdir_p("assets")

      runner = spawnless_runner(port: 9123)
      out, = capture_io { runner.command_run(["--desktop", "--port", "9100", "--no-reload"]) }

      env = runner.calls[:env]
      assert_equal "desktop", env["RUFLET_TARGET"]
      assert_equal "9123", env["RUFLET_PORT"]
      assert_equal "1", env["RUFLET_SUPPRESS_SERVER_BANNER"]
      assert_equal File.realpath(File.join(dir, "assets")), File.realpath(env["RUFLET_ASSETS_DIR"])
      assert_equal false, runner.calls[:reload]
      assert_equal 9100, runner.calls[:requested_port]
      assert_includes out, "Requested port 9100 is busy; bound to 9123"
      assert_includes out, "Ruflet desktop URL: http://localhost:9123"
    end
  end

  def test_mobile_is_the_default_target_and_shows_the_qr_hint
    in_project do
      File.write("main.rb", "")
      runner = spawnless_runner
      capture_io { runner.command_run([]) }

      assert_equal "mobile", runner.calls[:env]["RUFLET_TARGET"]
      assert_nil runner.calls[:env]["RUFLET_ASSETS_DIR"]
      assert_equal true, runner.calls[:reload]
      assert_equal 8550, runner.calls[:qr_port]
    end
  end

  def test_web_needs_a_web_client
    in_project do
      File.write("main.rb", "")

      runner = spawnless_runner(web_client: nil)
      _out, err = capture_io { assert_equal 1, runner.command_run(["--web"]) }
      assert_includes err, "Web client build not found and prebuilt download failed."
      assert_nil runner.calls[:env], "no child without a web client"

      runner = spawnless_runner(web_client: "/tmp/ruflet-web")
      capture_io { runner.command_run(["--web"]) }
      assert_equal "/tmp/ruflet-web", runner.calls[:env]["RUFLET_WEB_CLIENT_DIR"]
    end
  end

  def test_no_free_port_fails
    in_project do
      File.write("main.rb", "")
      runner = spawnless_runner(port: nil)
      capture_io { assert_equal 1, runner.command_run([]) }
      assert_nil runner.calls[:env]
    end
  end

  def test_resolve_backend_port_falls_back_to_8550_for_non_positive_ports
    runner = DummyRunner.new
    asked = []
    runner.define_singleton_method(:find_available_port) { |base| asked << base; base }
    [0, -5, 9000].each { |port| runner.send(:resolve_backend_port, "mobile", requested_port: port) }
    assert_equal [8550, 8550, 9000], asked
  end

  private

  class SpawnlessRunner < DummyRunner
    attr_reader :calls

    def initialize(port:, web_client:)
      super()
      @calls = {}
      @port = port
      @web_client = web_client
    end

    def resolve_backend_port(_target, requested_port: 8550)
      @calls[:requested_port] = requested_port
      @port
    end

    def detect_web_client_dir = @web_client
    def apply_local_ruflet_dev_overrides(_env) = nil
    def print_mobile_qr_hint(port:) = (@calls[:qr_port] = port)

    # Stop here: returning nil makes command_run exit 1 before it spawns.
    def build_runtime_command(script_path, gemfile_path:, env:, reload: false)
      @calls[:script] = script_path
      @calls[:env] = env
      @calls[:reload] = reload
      nil
    end
  end

  def spawnless_runner(port: 8550, web_client: "/tmp/ruflet-web")
    SpawnlessRunner.new(port: port, web_client: web_client)
  end

  def in_project
    Dir.mktmpdir { |dir| Dir.chdir(dir) { yield dir } }
  end
end
