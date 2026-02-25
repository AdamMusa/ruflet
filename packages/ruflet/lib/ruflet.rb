# frozen_string_literal: true

require "thread"
require "ruflet_ui"
require "ruflet_server"

module Ruflet
  @run_interceptors = []
  @run_interceptors_mutex = Mutex.new

  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: 8550, &block)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)

    interceptor = @run_interceptors_mutex.synchronize { @run_interceptors.last }
    if interceptor
      result = interceptor.call(entrypoint: callback, host: host, port: port)
      return result unless result == :pass
    end

    Server.new(host: host, port: port) do |page|
      callback.call(page)
    end.start
  end

  def with_run_interceptor(interceptor)
    @run_interceptors_mutex.synchronize { @run_interceptors << interceptor }
    yield
  ensure
    @run_interceptors_mutex.synchronize { @run_interceptors.delete(interceptor) }
  end
end
