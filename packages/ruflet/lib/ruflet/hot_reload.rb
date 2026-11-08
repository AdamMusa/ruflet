# frozen_string_literal: true

require "ruflet_core"

module Ruflet
  # Development-time hot reload for `ruflet run`.
  #
  # This module deliberately lives in the ruflet CLI gem: the ruby_runtime
  # prebuilt VM compiles every file under ruflet_core/lib and ruflet_server/lib
  # into self-contained production apps, so dev-only machinery must stay out of
  # those gems. The framework already exposes the two hooks hot reload needs:
  # Ruflet.with_run_interceptor to capture the app entrypoint block, and
  # Ruflet::Server#reload_app! to repaint live sessions over their open
  # WebSocket connections. Apps that start Ruflet::Server themselves
  # (`Ruflet.app { ... }.run`, or a ruflet_core whose Ruflet.run predates run
  # interceptors) are served through ServerStartCapture below instead.
  module HotReload
    Error = Class.new(StandardError)

    # Bytes the runner writes on the fd `ruflet run` passes in RUFLET_READY_FD
    # (see Ruflet::CLI::RunCommand). TRAP_ARMED: USR1 is trapped, so a reload
    # signal can no longer kill the app. READY: the app is captured, the
    # watcher runs and USR1 is still trapped, so a reload takes effect at
    # once. Neither is sent unless USR1 really is trapped; the fd is closed
    # after READY, or instead of it.
    TRAP_ARMED = "t"
    READY = "."

    # Fiber-local slot that holds the ScriptLoad of the app script a Runner
    # is loading on that fiber (see Runner#load_script!).
    SERVER_START_CAPTURE = :__ruflet_hot_reload_server_start_capture

    # One load of the app script by a Runner. ServerStartCapture finds it in
    # the fiber-local slot above, so only a Server#start the script makes
    # synchronously, on the fiber that loads it, ever reaches the runner.
    class ScriptLoad
      # pid: the process that loads; verbose: $VERBOSE as it was before the
      # load silenced it.
      attr_reader :pid, :verbose
      # What handed this load's entrypoint over first: :run (Ruflet.run,
      # through the run interceptor), :server (Server#start), or nil.
      attr_accessor :entrypoint

      def initialize(runner, reloading:, verbose:)
        @runner = runner
        @reloading = reloading
        @verbose = verbose
        @pid = Process.pid
        @entrypoint = nil
      end

      def reloading?
        @reloading
      end

      def server_start(server, app_block, start)
        @runner.send(:capture_server_start, self, server, app_block, start)
      end
    end

    # Prepended to Ruflet::Server. Without the runner, a Server#start that
    # the app script makes while it loads (`Ruflet.app { ... }.run`, or
    # Ruflet.run on a ruflet_core without run interceptors) serves the app
    # and blocks the script there. Under the runner it still does, with the
    # app's own server object, and the runner arms hot reload around it (see
    # Runner#capture_server_start). Every other start (on a thread or fiber
    # the app made, in a child it forked, outside a runner, or with an
    # in-process bridge) is not touched.
    module ServerStartCapture
      def start
        script_load = Thread.current[SERVER_START_CAPTURE]
        return super unless script_load && @app_block && @in_process_bridge.nil?

        script_load.server_start(self, @app_block, -> { super() })
      end
    end

    # Prepends ServerStartCapture to Ruflet::Server as soon as it exists,
    # without loading ruflet_server: whether Ruflet::Server is defined stays
    # up to the app, as without the runner (a DSL app that never requires
    # ruflet_server fails the same way under `ruflet run` as under ruby).
    def self.hook_server_start
      @server_hook_mutex.synchronize do
        next if @server_class_watch || hook_server_class

        # A :class event fires as `class Server` opens, before its body runs.
        @server_class_watch = TracePoint.new(:class) do |trace|
          begin
            server_class = trace.self
            # Module#name itself: an app class may define its own `name`.
            next unless Class === server_class && MODULE_NAME.bind_call(server_class) == "Ruflet::Server"

            trace.disable
            server_class.prepend(ServerStartCapture) unless server_class.include?(ServerStartCapture)
          rescue StandardError
            nil # never fail the class definition that is being opened
          end
        end
        @server_class_watch.enable
      end
      nil
    end

    def self.hook_server_class
      return false unless Ruflet.const_defined?(:Server, false) && !Ruflet.autoload?(:Server)

      server_class = Ruflet.const_get(:Server, false)
      return false unless server_class.is_a?(Class)

      server_class.prepend(ServerStartCapture) unless server_class.include?(ServerStartCapture)
      true
    end
    private_class_method :hook_server_class

    MODULE_NAME = Module.instance_method(:name)
    private_constant :MODULE_NAME
    @server_hook_mutex = Mutex.new
    @server_class_watch = nil

    DEFAULT_POLL_INTERVAL = 0.25
    EXCLUDED_DIRECTORIES = %w[
      .git
      .bundle
      .dart_tool
      .idea
      .ruby-lsp
      .vscode
      build
      coverage
      log
      node_modules
      pkg
      ruflet_client
      tmp
      vendor
    ].freeze

    def self.run(script:, watch_root: nil, poll_interval: DEFAULT_POLL_INTERVAL)
      Runner.new(script: script, watch_root: watch_root, poll_interval: poll_interval).run
    end

    class Runner
      attr_reader :server, :current_block, :reload_count

      def initialize(script:, watch_root: nil, poll_interval: DEFAULT_POLL_INTERVAL, server_factory: nil, logger: nil)
        @script = File.expand_path(script)
        raise Error, "script not found: #{@script}" unless File.file?(@script)

        root = watch_root.to_s.empty? ? File.dirname(@script) : watch_root
        @watch_root = File.expand_path(root)
        @poll_interval = poll_interval
        @server_factory = server_factory
        @logger = logger
        @current_block = nil
        @server = nil
        @watcher = nil
        @reload_count = 0
        @force_reload = false
        @reload_mutex = Mutex.new
        @served_from_script = false
      end

      def run
        @ready_io = claim_ready_fd
        # Before any app code: a reload signal that arrives while the app
        # loads is kept for the watcher instead of killing the app.
        report(TRAP_ARMED) if install_manual_reload_trap
        HotReload.hook_server_start
        return serve_app(interceptable: false) unless Ruflet.respond_to?(:with_run_interceptor)

        Ruflet.with_run_interceptor(run_interceptor) { serve_app(interceptable: true) }
      end

      def stop
        @watcher&.kill
        @watcher = nil
      end

      def watching?
        !@watcher.nil?
      end

      def request_reload
        @force_reload = true
      end

      def reload!
        @reload_mutex.synchronize do
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            prune_watched_features!
            load_script!(reloading: true)
            if @server.respond_to?(:reload_app!)
              @server.reload_app!
            else
              log "installed ruflet_server does not support reload_app!; clients keep the previous UI"
            end
            @reload_count += 1
            elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
            log "reloaded in #{elapsed_ms}ms"
          rescue Exception => e # rubocop:disable Lint/RescueException -- a broken script must never kill the dev loop
            raise if fatal_error?(e)

            log "reload failed: #{e.class}: #{e.message}"
            Array(e.backtrace).first(3).each { |line| log "  #{line}" }
          end
        end
      end

      def watched_files
        files = []
        directories = [@watch_root]
        until directories.empty?
          directory = directories.pop
          begin
            Dir.each_child(directory) do |name|
              # Prune before descending: generated Flutter/build trees can
              # contain thousands of files and are never reload inputs.
              next if name.start_with?(".") || EXCLUDED_DIRECTORIES.include?(name)

              path = File.join(directory, name)
              if File.directory?(path)
                directories << path unless File.symlink?(path)
              elsif name.end_with?(".rb") && File.file?(path)
                files << path
              end
            end
          rescue Errno::ENOENT, Errno::ENOTDIR, Errno::EACCES
            # Editors/build tools may remove a directory during a snapshot.
            next
          end
        end
        files.sort!
        files << @script unless files.include?(@script) || !File.file?(@script)
        files
      end

      private

      # Loads the app, which hands its entrypoint over by calling Ruflet.run
      # (and Ruflet::App#run) through the run interceptor, then serves it
      # here; or by starting Ruflet::Server itself, which ServerStartCapture
      # serves from inside the script (see capture_server_start). A ruflet_core
      # without run interceptors can only be caught the second way; if it is
      # not, the app just runs, without hot reload.
      def serve_app(interceptable:)
        loaded = load_script!
        # The app's own server was served from its script and has stopped,
        # and the rest of the script handed nothing else over.
        return loaded if @served_from_script && @server.nil?

        unless @server
          raise Error, "#{@script} never called Ruflet.run" if interceptable

          log "installed ruflet_core does not support run interceptors; running without hot reload"
          close_ready_io
          return loaded
        end

        arm_reload
        @server.start
      end

      # Watches the app's files and tells `ruflet run` the app is up.
      def arm_reload
        @snapshot = file_snapshot
        start_watcher
        # Again after the app code, which may have replaced the trap. Without
        # it, `ruflet run` must never send "r": USR1 would kill the app.
        install_manual_reload_trap ? signal_ready : close_ready_io
      end

      def run_interceptor
        @run_interceptor ||= lambda do |entrypoint:, host:, port:|
          script_load = Thread.current[SERVER_START_CAPTURE]
          script_load.entrypoint ||= :run if script_load.is_a?(ScriptLoad)
          @current_block = entrypoint
          @server ||= create_server(host: host, port: port)
          :ruflet_hot_reload
        end
      end

      # A Server#start the app script makes while load_script! runs it, on
      # the fiber that loads it (from ServerStartCapture; `start` starts that
      # server for real). Without the runner such a start serves the app and
      # blocks the script there, so:
      #
      # - On the first load it still does, with the app's own server object
      #   (its class, host and port). The runner only arms hot reload around
      #   it and makes that server serve the latest block. Code after the
      #   start runs once the server stops, as without the runner.
      # - On a reload the app is served already: the start hands the new
      #   block over and the load ends there, the way it blocked there the
      #   first time. Only the load's first entrypoint is the app's.
      # - A start in a process the app forked, and, on the first load, one
      #   after an intercepted Ruflet.run (a server Ruflet.run did not start
      #   and that ran on v0.0.23 as is), runs as without the runner.
      def capture_server_start(script_load, server, app_block, start)
        return start.call unless Process.pid == script_load.pid

        if script_load.reloading?
          @current_block = app_block unless script_load.entrypoint || server.equal?(@server)
          script_load.entrypoint ||= :server
          throw script_load
        end
        return start.call if script_load.entrypoint || @server

        script_load.entrypoint = :server
        serve_from_script(script_load, server, app_block, start)
      end

      # Serves the app's own server from inside its script, the way it
      # serves without the runner, with hot reload armed around it.
      def serve_from_script(script_load, server, app_block, start)
        runner = self
        @current_block = app_block
        # The server calls this for each new session and on reload_app!, so
        # it always renders the block the latest load handed over.
        server.instance_variable_set(:@app_block, proc { |page| runner.current_block.call(page) })
        @server = server
        # Serving is not loading: warnings show again, and the app's own code
        # on this fiber (once the server stops) is no longer captured. Done
        # before the watcher starts, whose reloads save and restore $VERBOSE.
        Thread.current[SERVER_START_CAPTURE] = nil
        $VERBOSE = script_load.verbose
        arm_reload
        begin
          start.call
        ensure
          # Once it stops, the runner lets it go: the rest of the script runs
          # as it does on v0.0.23, so a Ruflet.run there is intercepted and
          # served by the runner's own server after the load.
          stop
          @server = nil
          @served_from_script = true
        end
      end

      def create_server(host:, port:)
        runner = self
        factory = @server_factory || method(:default_server_factory)
        factory.call(host: host, port: port) { |page| runner.current_block.call(page) }
      end

      def default_server_factory(host:, port:, &app_block)
        require "ruflet_server"
        Ruflet::Server.new(host: host, port: port, &app_block)
      end

      # The ScriptLoad is fiber-local, so ServerStartCapture only sees starts
      # the script makes synchronously, never ones on threads or fibers it
      # creates. On a reload a captured start ends the load (throw).
      def load_script!(reloading: false)
        previous_verbose = $VERBOSE
        $VERBOSE = nil
        previous_capture = Thread.current[SERVER_START_CAPTURE]
        script_load = ScriptLoad.new(self, reloading: reloading, verbose: previous_verbose)
        Thread.current[SERVER_START_CAPTURE] = script_load
        catch(script_load) { Kernel.load(@script) }
      ensure
        Thread.current[SERVER_START_CAPTURE] = previous_capture
        $VERBOSE = previous_verbose
      end

      def prune_watched_features!
        watched = {}
        watched_files.each do |path|
          watched[path] = true
          begin
            watched[File.realpath(path)] = true
          rescue Errno::ENOENT
            nil
          end
        end
        $LOADED_FEATURES.reject! { |feature| watched.key?(feature) }
      end

      def file_snapshot
        snapshot = {}
        watched_files.each do |path|
          begin
            snapshot[path] = File.mtime(path).to_f
          rescue Errno::ENOENT
            next
          end
        end
        snapshot
      end

      def start_watcher
        runner = self
        @watcher = Thread.new do
          Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
          runner.send(:watch_loop)
        end
      end

      def watch_loop
        loop do
          sleep @poll_interval
          forced = @force_reload
          current = file_snapshot
          next unless forced || current != @snapshot

          @force_reload = false
          # Give editors a moment to finish multi-file saves.
          sleep 0.05 unless forced
          @snapshot = file_snapshot
          reload!
        end
      end

      # True once USR1 is trapped; `ruflet run` is only told so then.
      def install_manual_reload_trap
        return false unless Signal.list.key?("USR1")

        Signal.trap("USR1") { @force_reload = true }
        true
      rescue ArgumentError, NotImplementedError
        false
      end

      # Takes the fd `ruflet run` passed in RUFLET_READY_FD before any app code
      # runs. It arrives without close-on-exec, so marking it and clearing the
      # variable keeps processes the app spawns while booting from inheriting
      # the pipe or seeing the variable; one of them could otherwise report
      # "ready" early and let a reload kill the booting app.
      def claim_ready_fd
        fd = ENV.delete("RUFLET_READY_FD").to_s
        return nil if fd.empty?

        io = IO.for_fd(Integer(fd), autoclose: true)
        io.close_on_exec = true
        io.sync = true
        io
      rescue ArgumentError, SystemCallError, IOError
        nil
      end

      # `ruflet run` holds "r" (USR1) until the app is up, and holds it
      # unconditionally until TRAP_ARMED: before the trap exists, USR1 would
      # kill the booting app.
      def report(byte)
        @ready_io&.write(byte)
      rescue SystemCallError, IOError
        close_ready_io
      end

      def signal_ready
        report(READY)
        close_ready_io
      end

      def close_ready_io
        io = @ready_io
        @ready_io = nil
        io&.close
      rescue SystemCallError, IOError
        nil
      end

      def fatal_error?(error)
        error.is_a?(SystemExit) || error.is_a?(SignalException) || error.is_a?(NoMemoryError)
      end

      def log(message)
        if @logger
          @logger.call(message)
        else
          warn "[ruflet reload] #{message}"
        end
      end
    end
  end
end
