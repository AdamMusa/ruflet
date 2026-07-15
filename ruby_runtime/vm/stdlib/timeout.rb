# frozen_string_literal: true

# Timeout for the single-threaded embedded VM. Without preemption a running
# block cannot be interrupted, so the block simply runs to completion.
module Timeout
  class Error < RuntimeError; end

  def self.timeout(_seconds, _klass = nil)
    yield
  end
end

module Kernel
  unless method_defined?(:timeout) || private_method_defined?(:timeout)
    def timeout(seconds, klass = nil, &block)
      Timeout.timeout(seconds, klass, &block)
    end
    private :timeout
  end
end
