# frozen_string_literal: true

# Cooperative Thread compatibility for mruby. Each logical thread runs in a
# Fiber on the VM's single native thread. The nonblocking server loop pumps
# ready fibers, while sleep yields until its deadline.
unless Object.const_defined?(:Thread)
  class Thread
    attr_accessor :abort_on_exception
    attr_writer :report_on_exception

    class << self
      def new(*args, &block)
        thread = allocate
        thread.__send__(:schedule_block, args, block)
        threads << thread
        thread
      end

      def current
        @current || main
      end

      def main
        @main ||= begin
          thread = allocate
          thread.__send__(:initialize_main)
          thread
        end
      end

      def pass
        if current == main
          pump
        else
          Fiber.yield
        end
        nil
      end

      def cooperative?
        true
      end

      def sleep_current(seconds)
        thread = current
        return native_sleep(seconds) if thread == main

        duration = seconds.nil? ? nil : seconds.to_f
        thread.__send__(:sleep_until, duration && monotonic_time + duration)
        Fiber.yield
        duration || 0
      end

      def pump
        now = monotonic_time
        runnable = threads.find do |thread|
          thread.alive? && (thread.__send__(:wake_at).nil? || thread.__send__(:wake_at) <= now)
        end
        return false unless runnable

        previous = @current
        @current = runnable
        runnable.__send__(:resume)
        @current = previous
        # Move the fiber that just ran to the back of the queue. Without this,
        # a frequently-ready socket fiber can permanently starve timers and
        # other background work that became ready later.
        threads.delete(runnable)
        threads << runnable if runnable.alive?
        threads.delete_if { |thread| !thread.alive? }
        true
      ensure
        @current = previous
      end

      def threads
        @threads ||= []
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      rescue StandardError
        Time.now.to_f
      end

      def native_sleep(seconds)
        __ruflet_native_sleep(seconds)
      end
    end

    def join(_limit = nil)
      while alive?
        if Thread.current == Thread.main
          Thread.pass
          Thread.__send__(:native_sleep, 0.001) if alive?
        else
          Thread.sleep_current(0.001)
        end
      end
      raise @error if @error

      self
    end

    def value
      join
      @value
    end

    def alive?
      @status != false && @fiber && @fiber.alive?
    end

    def kill
      @status = false
      self
    end
    alias terminate kill
    alias exit kill

    def status
      alive? ? @status : false
    end

    def raise(error = ::Interrupt, message = nil)
      Kernel.raise(message ? error.new(message) : error)
    end

    def [](key)
      (@locals ||= {})[key.to_sym]
    end

    def []=(key, value)
      (@locals ||= {})[key.to_sym] = value
    end

    private

    def initialize_main
      @status = "run"
      @fiber = Fiber.current
    end

    def schedule_block(args, block)
      thread = self
      @status = "run"
      @fiber = Fiber.new do
        thread.__send__(:run_block, args, block)
        thread.__send__(:finish)
      end
    end

    def run_block(args, block)
      @value = block.call(*args) if block
    rescue StandardError => e
      @error = e
    end

    def resume
      return unless alive?

      @wake_at = nil
      @status = "run"
      @fiber.resume
    end

    def sleep_until(deadline)
      @wake_at = deadline
      @status = "sleep"
    end

    attr_reader :wake_at

    def finish
      @status = false
    end
  end
end

module Kernel
  unless instance_methods.include?(:__ruflet_native_sleep) || private_instance_methods.include?(:__ruflet_native_sleep)
    alias __ruflet_native_sleep sleep

    def sleep(seconds = nil)
      if Object.const_defined?(:Thread) && Thread.respond_to?(:cooperative?)
        Thread.sleep_current(seconds)
      else
        __ruflet_native_sleep(seconds)
      end
    end
    private :sleep, :__ruflet_native_sleep
  end
end

unless Object.const_defined?(:Mutex)
  class Mutex
    def initialize
      @locked = false
    end

    def lock
      raise ThreadError, "deadlock; recursively locking mutex" if @locked

      @locked = true
      self
    end

    def unlock
      @locked = false
      self
    end

    def locked?
      @locked
    end

    def try_lock
      return false if @locked

      lock
      true
    end

    def synchronize
      lock
      begin
        yield
      ensure
        unlock
      end
    end
  end
end

unless Object.const_defined?(:ThreadError)
  class ThreadError < StandardError; end
end

unless Object.const_defined?(:ConditionVariable)
  class ConditionVariable
    def wait(mutex, timeout = nil)
      mutex.unlock
      sleep(timeout || 0.001)
      mutex.lock
      self
    end

    def signal = self
    def broadcast = self
  end
end

unless Object.const_defined?(:Queue)
  class Queue
    def initialize
      @items = []
    end

    def push(item)
      @items.push(item)
      self
    end
    alias << push
    alias enq push

    def pop(non_block = false)
      raise ThreadError, "queue empty" if @items.empty? && non_block
      sleep(0.001) while @items.empty? && Thread.current != Thread.main
      @items.shift
    end
    alias deq pop
    alias shift pop

    def empty? = @items.empty?
    def size = @items.length
    alias length size

    def clear
      @items.clear
      self
    end
  end
end
