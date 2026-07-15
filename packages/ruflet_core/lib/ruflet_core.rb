# frozen_string_literal: true

require "thread"
require "ruflet_protocol"
require "ruflet_ui"

module Ruflet
  @run_interceptors = []
  @run_interceptors_mutex = Mutex.new

  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: nil, &block)
    port = normalize_run_port(port || ENV["RUFLET_PORT"] || 8550)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)
    port = resolved_run_port(port)

    interceptor = @run_interceptors_mutex.synchronize { @run_interceptors.last }
    if interceptor
      result = interceptor.call(entrypoint: callback, host: host, port: port)
      return result unless result == :pass
    end

    begin
      require "ruflet_server"
    rescue LoadError => e
      raise LoadError, "Ruflet.run requires the 'ruflet_server' gem unless a run interceptor handles execution.", e.backtrace
    end

    Server.new(host: host, port: port) do |page|
      callback.call(page)
    end.start
  end

  def resolved_run_port(port)
    raw = port.nil? ? ENV["RUFLET_PORT"] : port
    return 8550 if raw.nil? || raw.to_s.strip.empty?

    value = raw.to_i
    value >= 0 ? value : 8550
  end

  def with_run_interceptor(interceptor)
    @run_interceptors_mutex.synchronize { @run_interceptors << interceptor }
    yield
  ensure
    @run_interceptors_mutex.synchronize { @run_interceptors.delete(interceptor) }
  end

  def normalize_run_port(value)
    Integer(value)
  rescue ArgumentError, TypeError
    8550
  end
end
