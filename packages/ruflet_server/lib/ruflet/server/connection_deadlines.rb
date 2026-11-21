# frozen_string_literal: true

module Ruflet
  # Closes connections that stall before they start working: an HTTP request
  # whose headers never finish arriving, or a WebSocket that never sends its
  # first message (a real client registers as soon as it connects). Without
  # this, each such socket keeps a thread and a file descriptor forever.
  #
  # One thread checks every deadline. It starts when the first deadline is
  # set and exits once none are left. The embedded mruby VM has no real
  # threads, so there deadlines are not enforced.
  class ConnectionDeadlines
    CHECK_INTERVAL = 0.2
    # Seconds a client has to finish sending its HTTP request headers. Puma
    # waits 30 s for a request's first data. Browsers open sockets ahead of
    # need and keep them unused for up to about 10 s (Chrome), so a deadline
    # that short would race them.
    HANDSHAKE_TIMEOUT_SECONDS = 30
    # Seconds an upgraded WebSocket has to send its first message. Real
    # clients send register_client at once.
    REGISTER_TIMEOUT_SECONDS = 30

    @shared_mutex = Mutex.new if Object.const_defined?(:Mutex)

    # The process-wide instance, or nil where deadlines are not enforced.
    def self.shared
      return nil unless supported?

      @shared_mutex.synchronize { @shared ||= new }
    end

    # Needs preemptive threads: a deadline thread that sleeps must not stall
    # the connection it watches. CRuby has them; the embedded mruby VM's
    # Thread is cooperative.
    def self.supported?
      return false if RUBY_ENGINE == "mruby"
      return false if Thread.respond_to?(:cooperative?) && Thread.cooperative?

      true
    end

    def initialize(check_interval: CHECK_INTERVAL)
      @check_interval = check_interval
      @entries = {}
      @mutex = Mutex.new
      @thread = nil
    end

    # Calls on_expire (from the deadline thread) unless cancel(key) comes
    # first. Watching a key again replaces its deadline.
    def watch(key, seconds, &on_expire)
      return nil if seconds.nil? || seconds <= 0 || on_expire.nil?

      @mutex.synchronize do
        @entries[key] = [monotonic_now + seconds, on_expire]
        @thread = Thread.new { run } unless @thread
      end
      key
    end

    def cancel(key)
      @mutex.synchronize { @entries.delete(key) }
      nil
    end

    def watching?(key)
      @mutex.synchronize { @entries.key?(key) }
    end

    private

    def run
      Thread.current.report_on_exception = false if Thread.current.respond_to?(:report_on_exception=)
      loop do
        sleep @check_interval
        expired = @mutex.synchronize do
          now = monotonic_now
          due = @entries.select { |_key, entry| entry[0] <= now }
          due.each_key { |key| @entries.delete(key) }
          due.values
        end

        expired.each do |entry|
          begin
            entry[1].call
          rescue StandardError
            nil
          end
        end

        done = @mutex.synchronize do
          if @entries.empty?
            @thread = nil
            true
          else
            false
          end
        end
        break if done
      end
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
