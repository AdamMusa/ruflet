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
  # interceptors) are served through ServerStartCapture below instead, also
  # when that start is in a file the script requires (InFlightRequires).
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

      # in_flight: on a reload, the RequiresInFlight of the app's own server
      # (see Runner#serve_from_script), which this load loads instead of
      # requiring (InFlightRequires).
      def initialize(runner, reloading:, verbose:, in_flight: nil)
        @runner = runner
        @reloading = reloading
        @verbose = verbose
        @pid = Process.pid
        @entrypoint = nil
        @in_flight = in_flight
        @loaded_in_flight = {}
      end

      def reloading?
        @reloading
      end

      def server_start(server, app_block, start)
        @runner.send(:capture_server_start, self, server, app_block, start)
      end

      # The path a `require` of feature would load, if it is a file in flight.
      def in_flight_path(feature)
        @in_flight&.path_for(feature)
      end

      # Loads a file in flight the way `require` would have: once per load,
      # and again on a later require if loading it raised.
      def load_in_flight(path)
        key = HotReload.realpath(path)
        return false if @loaded_in_flight.key?(key)

        @loaded_in_flight[key] = true
        begin
          Kernel.load(path)
        rescue Exception # rubocop:disable Lint/RescueException -- only undoes the mark, then re-raises
          @loaded_in_flight.delete(key)
          raise
        end
        true
      end
    end

    # The files whose `require` the fiber serving the app's own server is
    # still inside of, by real path: main.rb requires app.rb, which ends with
    # `Ruflet.app { ... }.run`, so that fiber serves from inside app.rb's
    # require, and Ruby's lock on that require is held until the server
    # stops. A reload loads main.rb again on the watcher thread; its
    # `require_relative "app"` would wait on that lock forever.
    class RequiresInFlight
      def initialize(paths)
        @paths = paths.to_h { |path| [path, true] }
        # Most requires name none of these files: told apart by name alone
        # (in any case: a file system may not tell "App" from "app").
        @names = paths.to_h { |path| [File.basename(path, ".rb").downcase, true] }
      end

      def path_for(feature)
        return nil unless @names.key?(File.basename(File.path(feature), ".rb").downcase)

        found = $LOAD_PATH.resolve_feature_path(feature)
        found.last if found && found.first == :rb && @paths.key?(HotReload.realpath(found.last))
      rescue LoadError, TypeError, ArgumentError, EncodingError, SystemCallError
        nil # Kernel#require reports a bad feature as it always has
      end
    end

    # While a reload of an app served from inside a required file runs (see
    # RequiresInFlight), the reloading fiber loads those files where the
    # script requires them, instead of waiting on their require locks. Every
    # other require, and every require on another fiber or thread, goes to
    # Kernel's own methods.
    #
    # Prepended to Object the first time such a reload runs. It has these
    # methods only while one does, so at any other time, and for any other
    # app, Kernel's own require and require_relative are all there is. Not
    # prepended to Kernel: gems such as Zeitwerk and bootsnap alias
    # Kernel#require, and one loaded during a reload would alias these
    # methods there and keep calling them once they are gone.
    module InFlightRequires
      # The interpreter's own require, which Kernel#require_relative calls
      # directly, bypassing RubyGems' and others' Kernel#require.
      CORE_REQUIRE =
        if Kernel.private_method_defined?(:gem_original_require)
          Kernel.instance_method(:gem_original_require)
        else
          Kernel.instance_method(:require)
        end

      METHODS = proc do
        def require(feature)
          script_load = Thread.current[SERVER_START_CAPTURE]
          path = script_load.in_flight_path(feature) if script_load.is_a?(ScriptLoad)
          path ? script_load.load_in_flight(path) : super
        end

        # Kernel#require_relative resolves against its Ruby caller, which
        # would be this file, so this resolves as it does: against the real
        # path of the file that calls it.
        def require_relative(feature)
          location = caller_locations(1, 1).first
          base = location && (location.absolute_path || location.path)
          raise LoadError, "cannot infer basepath" if base.nil? || base.start_with?("(eval")

          path = File.absolute_path(feature, File.dirname(base))
          script_load = Thread.current[SERVER_START_CAPTURE]
          in_flight = script_load.in_flight_path(path) if script_load.is_a?(ScriptLoad)
          in_flight ? script_load.load_in_flight(in_flight) : CORE_REQUIRE.bind_call(self, path)
        end

        private :require, :require_relative
      end
      private_constant :CORE_REQUIRE, :METHODS

      @mutex = Mutex.new
      @reloads = 0

      def self.around
        @mutex.synchronize do
          Object.prepend(self) unless Object.ancestors.include?(self)
          module_eval(&METHODS) if @reloads.zero?
          @reloads += 1
        end
        begin
          yield
        ensure
          @mutex.synchronize do
            @reloads -= 1
            remove_method(:require, :require_relative) if @reloads.zero?
          end
        end
      end
    end

    def self.realpath(path)
      File.realpath(path)
    rescue SystemCallError
      File.expand_path(path)
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
        @requires_in_flight = nil
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
      # - Unless the app's own server has stopped since, and the runner
      #   serves what the rest of the script handed over (a Ruflet.run after
      #   that start): on the first load that start returned once its server
      #   stopped, so on a reload it returns at once, without starting, and
      #   the load goes on to what the runner serves.
      # - A start in a process the app forked, and, on the first load, one
      #   after an intercepted Ruflet.run (a server Ruflet.run did not start
      #   and that ran on v0.0.23 as is), runs as without the runner.
      def capture_server_start(script_load, server, app_block, start)
        return start.call unless Process.pid == script_load.pid

        if script_load.reloading?
          return nil if @served_from_script && script_load.entrypoint.nil?

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
        # Reloads load these files instead of waiting on their requires.
        @requires_in_flight = requires_in_flight
        # Serving is not loading: warnings show again (as the app had them
        # before the load silenced them, or as the script set them while it
        # loaded), and the app's own code on this fiber (once the server
        # stops) is no longer captured. Done before the watcher starts, whose
        # reloads save and restore $VERBOSE.
        Thread.current[SERVER_START_CAPTURE] = nil
        loading_verbose = $VERBOSE
        $VERBOSE = script_load.verbose if loading_verbose.nil?
        arm_reload
        begin
          start.call
        ensure
          # Once it stops, the runner lets it go: the rest of the script runs
          # as it does on v0.0.23, inside the load and with its $VERBOSE, so
          # a Ruflet.run there is intercepted and served by the runner's own
          # server after the load. The requires it served from inside of
          # finish with it.
          stop
          @server = nil
          @requires_in_flight = nil
          @served_from_script = true
          $VERBOSE = loading_verbose
        end
      end

      # Labels of the top-level frame of a file being required or loaded:
      # "<top (required)>", or, where a compile cache such as bootsnap's
      # compiled the file, "<main>" (InstructionSequence.compile_file) or
      # "<compiled>" (InstructionSequence.compile from the file's source,
      # which bootsnap uses on Rubies with Ruby bug #22023: 3.3, 3.4.0-3.4.9
      # and 4.0.0-4.0.3 with Prism).
      TOP_LEVEL_LABELS = ["<top (required)>", "<main>", "<compiled>"].freeze
      private_constant :TOP_LEVEL_LABELS

      # The files whose top-level code is on the serving fiber's stack above
      # the script's own: the requires it serves from inside of. Nil if there
      # are none (`.run` in the script), and reloads stay as they were.
      #
      # The script's top level is the bottom-most frame in the script,
      # whatever its label: a method the script defines can also run above a
      # file it requires. Below it are the runner's callers, such as the
      # harness's own top-level code, which no reload requires.
      def requires_in_flight
        script = HotReload.realpath(@script)
        frames = caller_locations.filter_map do |location|
          path = location.absolute_path || location.path
          [location.label, HotReload.realpath(path)] if path
        end
        script_top = frames.rindex { |_label, path| path == script }
        return nil unless script_top

        paths = frames.first(script_top).filter_map do |label, path|
          path if TOP_LEVEL_LABELS.include?(label) && path != script
        end
        paths.empty? ? nil : RequiresInFlight.new(paths.uniq)
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
      # creates. On a reload a captured start ends the load (throw), and the
      # files the app's own server serves from inside the require of are
      # loaded instead of required (InFlightRequires).
      def load_script!(reloading: false)
        previous_verbose = $VERBOSE
        $VERBOSE = nil
        previous_capture = Thread.current[SERVER_START_CAPTURE]
        in_flight = reloading ? @requires_in_flight : nil
        script_load = ScriptLoad.new(self, reloading: reloading, verbose: previous_verbose, in_flight: in_flight)
        Thread.current[SERVER_START_CAPTURE] = script_load
        catch(script_load) do
          in_flight ? InFlightRequires.around { Kernel.load(@script) } : Kernel.load(@script)
        end
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
