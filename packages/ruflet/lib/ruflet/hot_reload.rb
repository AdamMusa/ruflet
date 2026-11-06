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
    # signal can no longer kill the app. READY: the app is captured and the
    # watcher runs, so a reload takes effect at once; the fd is then closed.
    TRAP_ARMED = "t"
    READY = "."

    # Prepended to Ruflet::Server: while a runner is active, Server#start is
    # captured the way Ruflet.run is, so the server the app built is never
    # started and the runner serves its block instead. Outside a runner, and
    # for the runner's own server, start is untouched.
    module ServerStartCapture
      def start
        capture = HotReload.server_start_capture
        return super unless capture && @app_block && @in_process_bridge.nil?

        result = capture.call(server: self, host: @host, port: @port, entrypoint: @app_block)
        result == :pass ? super : result
      end
    end

    @server_start_captures = []
    @server_start_captures_mutex = Mutex.new

    # True once Ruflet::Server can be captured. Loads ruflet_server early for
    # that: an app that starts the server itself references Ruflet::Server.
    def self.install_server_start_hook
      require "ruflet_server"
      server_class = Ruflet::Server
      server_class.prepend(ServerStartCapture) unless server_class.ancestors.include?(ServerStartCapture)
      true
    rescue LoadError, NameError
      false
    end

    def self.server_start_capture
      @server_start_captures_mutex.synchronize { @server_start_captures.last }
    end

    def self.with_server_start_capture(capture)
      @server_start_captures_mutex.synchronize { @server_start_captures << capture }
      yield
    ensure
      @server_start_captures_mutex.synchronize { @server_start_captures.delete(capture) }
    end

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
        install_manual_reload_trap
        report(TRAP_ARMED)

        capture_app_start do
          load_script!
          raise Error, "#{@script} never called Ruflet.run" unless @server

          @snapshot = file_snapshot
          start_watcher
          install_manual_reload_trap
          signal_ready
          @server.start
        end
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

      # Captures the app however it starts its server: Ruflet.run (and
      # Ruflet::App#run) through the run interceptor, anything that calls
      # Ruflet::Server#start itself through ServerStartCapture.
      def capture_app_start(&block)
        interceptable = Ruflet.respond_to?(:with_run_interceptor)
        server_hooked = HotReload.install_server_start_hook
        unless interceptable || server_hooked
          log "installed ruflet_core does not support run interceptors; running without hot reload"
          return load_script!
        end

        body = interceptable ? -> { Ruflet.with_run_interceptor(run_interceptor, &block) } : block
        return body.call unless server_hooked

        HotReload.with_server_start_capture(server_start_capture) { body.call }
      end

      def run_interceptor
        @run_interceptor ||= lambda do |entrypoint:, host:, port:|
          @current_block = entrypoint
          @server ||= create_server(host: host, port: port)
          :ruflet_hot_reload
        end
      end

      def server_start_capture
        @server_start_capture ||= lambda do |server:, entrypoint:, host:, port:|
          next :pass if server.equal?(@server)

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

      def load_script!
        previous_verbose = $VERBOSE
        $VERBOSE = nil
        Kernel.load(@script)
      ensure
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

      def install_manual_reload_trap
        return unless Signal.list.key?("USR1")

        Signal.trap("USR1") { @force_reload = true }
      rescue ArgumentError, NotImplementedError
        nil
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
