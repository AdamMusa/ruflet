# frozen_string_literal: true

require "ruflet_core"
require_relative "ruflet/server"

module Ruflet
  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: 8550, &block)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)

    interceptor = run_interceptor
    if interceptor
      result = interceptor.call(entrypoint: callback, host: host, port: port)
      return result unless result == :pass
    end

    Server.new(host: host, port: port) do |page|
      callback.call(page)
    end.start
  end

  def run_interceptor
    return nil unless instance_variable_defined?(:@run_interceptors_mutex)
    return nil unless instance_variable_defined?(:@run_interceptors)

    @run_interceptors_mutex.synchronize { @run_interceptors.last }
  end
  private_class_method :run_interceptor
end
