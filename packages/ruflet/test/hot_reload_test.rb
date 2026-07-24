# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

$LOAD_PATH.unshift(File.expand_path("../../ruflet_core/lib", __dir__))
require "ruflet/hot_reload"

class RufletHotReloadTest < Minitest::Test
  class FakeServer
    attr_reader :app_block, :reload_count

    def initialize(&app_block)
      @app_block = app_block
      @reload_count = 0
      @queue = Queue.new
    end

    def start
      @queue.pop
    end

    def reload_app!
      @reload_count += 1
    end

    def shutdown
      @queue << :stop
    end
  end

  class RecorderPage
    attr_reader :added

    def initialize
      @added = []
    end

    def add(value)
      @added << value
    end
  end

  def setup
    @dir = Dir.mktmpdir("ruflet-hot-reload-")
    @script = File.join(@dir, "main.rb")
    @logs = []
  end

  def teardown
    @runner&.server&.shutdown
    @thread&.join(2)
    @thread&.kill
    @runner&.stop
    FileUtils.remove_entry(@dir) if @dir && File.directory?(@dir)
  end

  def test_captures_app_block_without_starting_a_real_server
    write_widgets("v1")
    write_main
    start_runner

    assert_instance_of FakeServer, @runner.server
    assert_equal ["v1"], render
  end

  def test_file_change_reloads_required_files_and_swaps_the_block
    write_widgets("v1")
    write_main
    start_runner

    write_widgets("v2")
    wait_until("first reload") { @runner.reload_count >= 1 }

    assert_equal 1, @runner.server.reload_count
    assert_equal ["v2"], render
  end

  def test_broken_script_keeps_previous_block_and_recovers
    write_widgets("v1")
    write_main
    start_runner

    File.write(File.join(@dir, "widgets.rb"), "def broken(\n")
    wait_until("reload failure log") { @logs.any? { |line| line.include?("reload failed") } }

    assert_equal 0, @runner.reload_count
    assert_equal ["v1"], render, "a broken reload must keep the last good UI block"

    write_widgets("v3")
    wait_until("recovery reload") { @runner.reload_count >= 1 }
    assert_equal ["v3"], render
  end

  def test_manual_reload_request_triggers_without_file_changes
    write_widgets("v1")
    write_main
    start_runner

    @runner.request_reload
    wait_until("forced reload") { @runner.reload_count >= 1 }
    assert_equal ["v1"], render
  end

  def test_watched_files_excludes_vendored_and_hidden_paths
    write_widgets("v1")
    write_main
    vendored = File.join(@dir, "vendor", "bundle", "gem.rb")
    hidden = File.join(@dir, ".cache", "generated.rb")
    [vendored, hidden].each do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "# ignored\n")
    end

    runner = Ruflet::HotReload::Runner.new(script: @script, logger: ->(msg) { @logs << msg })
    watched = runner.watched_files

    assert_includes watched, @script
    assert_includes watched, File.join(@dir, "widgets.rb")
    refute_includes watched, vendored
    refute_includes watched, hidden
  end

  def test_script_that_never_calls_ruflet_run_raises
    File.write(@script, "# no Ruflet.run here\n")
    runner = Ruflet::HotReload::Runner.new(
      script: @script,
      server_factory: ->(host:, port:, &block) { FakeServer.new(&block) },
      logger: ->(msg) { @logs << msg }
    )

    error = assert_raises(Ruflet::HotReload::Error) { runner.run }
    assert_match(/never called Ruflet.run/, error.message)
  end

  private

  def write_main
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"

      Ruflet.run do |page|
        page.add(WIDGET_LABEL)
      end
    RUBY
  end

  def write_widgets(label)
    File.write(File.join(@dir, "widgets.rb"), "WIDGET_LABEL = #{label.inspect}\n")
  end

  def start_runner
    @runner = Ruflet::HotReload::Runner.new(
      script: @script,
      poll_interval: 0.05,
      server_factory: ->(host:, port:, &block) { FakeServer.new(&block) },
      logger: ->(msg) { @logs << msg }
    )
    @thread = Thread.new { @runner.run }
    wait_until("runner start") { @runner.watching? }
  end

  def render
    page = RecorderPage.new
    @runner.server.app_block.call(page)
    page.added
  end

  def wait_until(what, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until (value = yield)
      flunk "timed out waiting for #{what}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.02
    end
    value
  end
end
