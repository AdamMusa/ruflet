# frozen_string_literal: true

# Cooperative Thread/Mutex for the single-threaded embedded VM.
#
# mruby has no OS threads. Thread.new runs its block immediately and
# synchronization primitives are no-ops. Code that relies on true
# preemption will not gain concurrency, but thread-safe code (the common
# case: guarding shared state, spawning workers) runs correctly in
# sequential order.
unless Object.const_defined?(:Thread)
  class Thread
    attr_accessor :abort_on_exception
    attr_writer :report_on_exception

    def self.new(*args, &block)
      thread = allocate
      thread.__send__(:run_block, args, block)
      thread
    end

    def self.current
      @current ||= allocate
    end

    def self.main
      current
    end

    def self.pass
      nil
    end

    def join(_limit = nil)
      raise @error if @error

      self
    end

    def value
      join
      @value
    end

    def alive?
      false
    end

    def kill
      self
    end
    alias terminate kill
    alias exit kill

    def status
      false
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

    def run_block(args, block)
      @value = block.call(*args) if block
    rescue StandardError => e
      @error = e
    end
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
    def wait(mutex, _timeout = nil)
      # Single-threaded VM: nothing can signal while we wait, so return.
      mutex
    end

    def signal
      self
    end

    def broadcast
      self
    end
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

      @items.shift
    end
    alias deq pop
    alias shift pop

    def empty?
      @items.empty?
    end

    def size
      @items.length
    end
    alias length size

    def clear
      @items.clear
      self
    end
  end
end
