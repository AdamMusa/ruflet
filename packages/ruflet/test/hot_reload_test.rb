# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "rbconfig"
require "minitest/mock"

$LOAD_PATH.unshift(File.expand_path("../../ruflet_core/lib", __dir__))
# The runner hooks Ruflet::Server#start; keep it on this checkout's server,
# not an installed ruflet_server gem.
$LOAD_PATH.unshift(File.expand_path("../../ruflet_server/lib", __dir__))
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

    # What a DSL app's block calls on the page before adding its roots.
    def set_view_props(_props); end

    def labels
      @added.map { |item| item.respond_to?(:props) ? item.props["value"] : item }
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

  def test_reports_ready_on_the_cli_fd_once_reload_is_armed
    write_widgets("v1")
    write_main
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    # The limit only stops a runner that never reports from hanging the suite.
    assert IO.select([reader], nil, nil, 10), "the runner must report ready to `ruflet run`"
    assert_equal "t.", reader.read, "the runner reports its USR1 trap, then ready, then closes the fd"
    assert_nil ENV["RUFLET_READY_FD"], "the fd number must not leak to app subprocesses"
    assert @runner.watching?, "ready means the watcher and USR1 trap are armed"
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # The CLI's readiness fd reaches the app child without close-on-exec (spawn
  # maps it in), so anything the app spawned while loading inherited the pipe
  # and saw RUFLET_READY_FD; such a process could report "ready" early and
  # let a reload kill the booting app. The probe is a real subprocess that
  # the app script runs during load and that reports what it inherited.
  def test_processes_spawned_while_the_app_loads_do_not_inherit_the_ready_fd
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    writer.close_on_exec = false # as `ruflet run` hands it to the app child
    probe = File.join(@dir, "probe.rb")
    File.write(probe, <<~RUBY)
      begin
        IO.for_fd(Integer(ARGV[0]), autoclose: false)
        print "inherited"
      rescue Errno::EBADF
        print "closed"
      end
      print " env=", ENV["RUFLET_READY_FD"].inspect
    RUBY
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"
      $ready_fd_probe = `\#{RbConfig.ruby.inspect} \#{#{probe.inspect}.inspect} #{writer.fileno}`
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    assert IO.select([reader], nil, nil, 10), "the runner must still report ready"
    assert_equal "t.", reader.read
    assert_equal "closed env=nil", $ready_fd_probe
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # `ruflet run` holds "r" until the app reports, and falls back to sending
  # USR1 if the app is armed but never reports ready. That fallback is only
  # safe because the trap exists before any app code runs, which "t" says.
  def test_reports_the_usr1_trap_before_the_app_script_runs
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    $ready_reader = reader
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"
      $ready_bytes_at_load = $ready_reader.read_nonblock(8, exception: false)
      Ruflet.run { |page| page.add(WIDGET_LABEL) }
    RUBY
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    assert_equal "t", $ready_bytes_at_load, "the trap must be reported before the app loads, and ready only after"
    assert IO.select([reader], nil, nil, 10), "the runner must report ready once the app is up"
    assert_equal ".", reader.read
  ensure
    ENV.delete("RUFLET_READY_FD")
    $ready_reader = nil
    reader&.close
  end

  # `Ruflet.app { ... }.run` starts Ruflet::Server directly instead of going
  # through Ruflet.run. The runner never saw it, so the app never reported
  # ready (`ruflet run` queued "r" forever) and file changes never reloaded.
  def test_dsl_app_run_is_captured_like_ruflet_run
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require "ruflet_server"
      require_relative "widgets"

      Ruflet.app(host: "127.0.0.1", port: 0) { text(WIDGET_LABEL) }.run
    RUBY
    reader, writer = IO.pipe
    writer.autoclose = false # the runner owns and closes this fd
    ENV["RUFLET_READY_FD"] = writer.fileno.to_s

    start_runner

    assert_instance_of FakeServer, @runner.server, "the app's own server must not start"
    assert_equal ["v1"], render_labels
    assert IO.select([reader], nil, nil, 10), "a DSL app must report ready to `ruflet run`"
    assert_equal "t.", reader.read

    write_widgets("v2")
    wait_until("DSL reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render_labels
    assert_equal 1, @runner.server.reload_count
  ensure
    ENV.delete("RUFLET_READY_FD")
    reader&.close
  end

  # A ruflet_core without Ruflet.with_run_interceptor starts the server from
  # Ruflet.run itself. The runner used to give up on hot reload there and
  # never report ready; Server#start is captured instead. With no
  # interceptor registered, this checkout's Ruflet.run takes that same path.
  def test_server_start_is_captured_when_ruflet_core_has_no_run_interceptors
    write_widgets("v1")
    File.write(@script, <<~RUBY)
      require "ruflet"
      require_relative "widgets"

      Ruflet.run(host: "127.0.0.1", port: 0) { |page| page.add(WIDGET_LABEL) }
    RUBY
    without_run_interceptors do
      start_runner # the runner looks for run interceptors as it starts
    end

    assert_instance_of FakeServer, @runner.server
    assert_equal ["v1"], render
    write_widgets("v2")
    wait_until("reload") { @runner.reload_count >= 1 }
    assert_equal ["v2"], render
  end

  # The runner's own server is a Ruflet::Server too; capturing its start
  # would leave the app with no server at all.
  def test_the_runners_own_server_still_starts
    require "ruflet_server"
    write_widgets("v1")
    write_main
    with_server_banner_suppressed do
      @runner = Ruflet::HotReload::Runner.new(
        script: @script,
        poll_interval: 0.05,
        server_factory: ->(host:, port:, &block) { Ruflet::Server.new(host: "127.0.0.1", port: 0, &block) },
        logger: ->(msg) { @logs << msg }
      )
      @thread = Thread.new { @runner.run }
      wait_until("own server bound") { @runner.server&.port.to_i.positive? }
    end
    assert @runner.watching?
  ensure
    @runner&.server&.stop
    @thread&.join(2)
    @runner&.stop
    @runner = nil # teardown's FakeServer#shutdown does not apply
  end

  def test_server_start_outside_a_runner_is_untouched
    require "ruflet_server"
    Ruflet::HotReload.install_server_start_hook
    with_server_banner_suppressed do
      server = Ruflet::Server.new(host: "127.0.0.1", port: 0) { |_page| nil }
      thread = Thread.new { server.start }
      wait_until("server bound") { server.port.to_i.positive? }
    ensure
      server&.stop
      thread&.join(2)
    end
  end

  def test_without_the_cli_fd_nothing_is_reported
    write_widgets("v1")
    write_main
    ENV.delete("RUFLET_READY_FD")

    start_runner

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

  def test_excluded_trees_are_not_traversed
    write_main
    ignored = %w[build vendor .cache node_modules].map { |name| File.join(@dir, name) }
    ignored.each do |path|
      FileUtils.mkdir_p(File.join(path, "deep"))
      File.write(File.join(path, "deep", "generated.rb"), "# ignored")
    end
    entered = []
    each_child = Dir.method(:each_child)
    Dir.stub(:each_child, ->(path, &block) { entered << path; each_child.call(path, &block) }) do
      runner = Ruflet::HotReload::Runner.new(script: @script)
      assert_equal [@script], runner.watched_files
    end
    assert_equal [@dir], entered
  end

  def test_nested_files_and_file_symlinks_are_watched_without_following_directory_links
    write_main
    nested = File.join(@dir, "lib", "widget.rb")
    FileUtils.mkdir_p(File.dirname(nested))
    File.write(nested, "# widget")
    alias_path = File.join(@dir, "alias.rb")
    File.symlink(nested, alias_path)
    File.symlink(@dir, File.join(@dir, "loop"))
    runner = Ruflet::HotReload::Runner.new(script: @script)
    assert_equal [@script, nested, alias_path].sort, runner.watched_files
  end

  def test_explicit_entrypoint_is_kept_when_outside_watch_root
    write_main
    root = File.join(@dir, "lib")
    FileUtils.mkdir_p(root)
    runner = Ruflet::HotReload::Runner.new(script: @script, watch_root: root)
    assert_equal [@script], runner.watched_files
  end

  def test_directory_removed_during_snapshot_does_not_stop_watcher
    write_main
    removed = File.join(@dir, "removed")
    FileUtils.mkdir_p(removed)
    each_child = Dir.method(:each_child)
    Dir.stub(:each_child, lambda { |path, &block|
      raise Errno::ENOENT, path if path == removed
      each_child.call(path, &block)
    }) do
      runner = Ruflet::HotReload::Runner.new(script: @script)
      assert_equal [@script], runner.watched_files
    end
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

  def render_labels
    page = RecorderPage.new
    @runner.server.app_block.call(page)
    page.labels
  end

  def with_server_banner_suppressed
    previous = ENV["RUFLET_SUPPRESS_SERVER_BANNER"]
    ENV["RUFLET_SUPPRESS_SERVER_BANNER"] = "1"
    yield
  ensure
    previous.nil? ? ENV.delete("RUFLET_SUPPRESS_SERVER_BANNER") : ENV["RUFLET_SUPPRESS_SERVER_BANNER"] = previous
  end

  # Simulates a ruflet_core from before Ruflet.with_run_interceptor existed.
  def without_run_interceptors
    singleton = Ruflet.singleton_class
    singleton.send(:alias_method, :__test_with_run_interceptor, :with_run_interceptor)
    singleton.send(:remove_method, :with_run_interceptor)
    yield
  ensure
    singleton.send(:alias_method, :with_run_interceptor, :__test_with_run_interceptor)
    singleton.send(:remove_method, :__test_with_run_interceptor)
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
