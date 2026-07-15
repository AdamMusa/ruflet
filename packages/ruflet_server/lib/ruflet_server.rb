# frozen_string_literal: true

require "ruflet_core"
require_relative "ruflet/server"

module Ruflet
  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: nil, &block)
    port = normalize_run_port(port || ENV["RUFLET_PORT"] || 8550)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)
    port = resolved_run_port(port) if respond_to?(:resolved_run_port)
    port = 8550 if port.nil?

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

  def normalize_run_port(value)
    Integer(value)
  rescue ArgumentError, TypeError
    8550
  end
  class << self
    private :run_interceptor, :normalize_run_port
  end
end
