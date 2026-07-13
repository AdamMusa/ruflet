# frozen_string_literal: true

require "ruflet_core"
require_relative "ruflet/server"

module Ruflet
  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: nil, &block)
    callback = entrypoint || block
    raise ArgumentError, "Ruflet.run requires a callable entrypoint or block" unless callback.respond_to?(:call)
    port = resolved_run_port(port) if respond_to?(:resolved_run_port)
    port = 8550 if port.nil?

    Server.new(host: host, port: port) do |page|
      callback.call(page)
    end.start
  end
end
