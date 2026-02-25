# frozen_string_literal: true

require_relative "rack/context"
require_relative "rack/middleware"
require_relative "rack/runner"

module Ruflet
  module Rack
    module_function

    def run(host: "0.0.0.0", port: 8550, &block)
      Runner.new(host: host, port: port, &block).run
    end

    def current_env
      Context.current_env
    end
  end
end
