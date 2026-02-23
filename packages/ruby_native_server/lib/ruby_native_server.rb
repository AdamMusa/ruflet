# frozen_string_literal: true

require "ruby_native_ui"
require_relative "ruby_native/server"

module RubyNative
  module_function

  def run(entrypoint = nil, host: "0.0.0.0", port: 8550, &block)
    callback = entrypoint || block
    raise ArgumentError, "RubyNative.run requires a callable entrypoint or block" unless callback.respond_to?(:call)

    Server.new(host: host, port: port) do |page|
      callback.call(page)
    end.start
  end
end
