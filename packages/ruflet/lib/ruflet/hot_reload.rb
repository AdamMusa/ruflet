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
  # WebSocket connections.
  module HotReload
    Error = Class.new(StandardError)

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
        unless Ruflet.respond_to?(:with_run_interceptor)
          log "installed ruflet_core does not support run interceptors; running without hot reload"
          return load_script!
        end

        Ruflet.with_run_interceptor(run_interceptor) do
          load_script!
          raise Error, "#{@script} never called Ruflet.run" unless @server

          @snapshot = file_snapshot
          start_watcher
          install_manual_reload_trap
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
        files = Dir.glob(File.join(@watch_root, "**", "*.rb")).reject { |path| excluded_path?(path) }
        files << @script unless files.include?(@script) || !File.file?(@script)
        files
      end

      private

      def run_interceptor
        @run_interceptor ||= lambda do |entrypoint:, host:, port:|
          @current_block = entrypoint
          @server ||= create_server(host: host, port: port)
          :ruflet_hot_reload
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

      def excluded_path?(path)
        relative = path.delete_prefix("#{@watch_root}#{File::SEPARATOR}")
        return false if relative == path

        relative.split(File::SEPARATOR).any? do |component|
          component.start_with?(".") || EXCLUDED_DIRECTORIES.include?(component)
        end
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
