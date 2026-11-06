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
  # interceptors) are captured by ServerStartCapture below instead.
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

    # Fiber-local slot that holds the capture while a Runner loads the app
    # script (see Runner#load_script!).
    SERVER_START_CAPTURE = :__ruflet_hot_reload_server_start_capture

    # Prepended to Ruflet::Server. A Server#start made synchronously by the
    # app script while the runner loads it is the one that would block that
    # load forever, like Ruflet.run does without the runner, so it is
    # captured the way Ruflet.run is: the server the app built is never
    # started and the runner serves its block instead. Every other start (on
    # a thread or fiber the app made, in a child it forked, after the load,
    # outside a runner, and the runner's own server) is untouched.
    module ServerStartCapture
      def start
        capture = Thread.current[SERVER_START_CAPTURE]
        return super unless capture && @app_block && @in_process_bridge.nil?

        result = capture.call(server: self, host: @host, port: @port, entrypoint: @app_block)
        result == :pass ? super : result
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
          server_class = trace.self
          next unless server_class.is_a?(Class) && server_class.name == "Ruflet::Server"

          trace.disable
          server_class.prepend(ServerStartCapture) unless server_class.include?(ServerStartCapture)
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
            load_script!
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
      # (and Ruflet::App#run) through the run interceptor, or by starting
      # Ruflet::Server itself through ServerStartCapture; then watches it and
      # serves it. A ruflet_core without run interceptors can only be caught
      # the second way; if it is not, the app just runs, without hot reload.
      def serve_app(interceptable:)
        loaded = load_script!
        unless @server
          raise Error, "#{@script} never called Ruflet.run" if interceptable

          log "installed ruflet_core does not support run interceptors; running without hot reload"
          close_ready_io
          return loaded
        end

        @snapshot = file_snapshot
        start_watcher
        # Again after the app code, which may have replaced the trap. Without
        # it, `ruflet run` must never send "r": USR1 would kill the app.
        install_manual_reload_trap ? signal_ready : close_ready_io
        @server.start
      end

      def run_interceptor
        @run_interceptor ||= lambda do |entrypoint:, host:, port:|
          @current_block = entrypoint
          @entrypoint_loaded = true
          @server ||= create_server(host: host, port: port)
          :ruflet_hot_reload
        end
      end

      # Called by ServerStartCapture for a Server#start the app script makes
      # while load_script! runs it. Only the first one of a load is the app's:
      # without the runner it blocks there, so the script never reaches a
      # later one. A start in a process the app forked passes through.
      def server_start_capture
        @server_start_capture ||= lambda do |server:, entrypoint:, host:, port:|
          next :pass if server.equal?(@server) || Process.pid != @loading_pid

          if @entrypoint_loaded
            log "ignoring another Ruflet::Server#start (port #{port}) while the app loads: " \
                "only the app's first server is served"
            next :ruflet_hot_reload
          end

          run_interceptor.call(entrypoint: entrypoint, host: host, port: port)
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

      # Fiber-local, so ServerStartCapture only sees starts the script makes
      # synchronously, never ones on threads or fibers it creates.
      def load_script!
        previous_verbose = $VERBOSE
        $VERBOSE = nil
        previous_capture = Thread.current[SERVER_START_CAPTURE]
        @loading_pid = Process.pid
        @entrypoint_loaded = false
        Thread.current[SERVER_START_CAPTURE] = server_start_capture
        Kernel.load(@script)
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
