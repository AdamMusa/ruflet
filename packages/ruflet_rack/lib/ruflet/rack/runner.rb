# frozen_string_literal: true

module Ruflet
  module Rack
    class Runner
      def initialize(host: "0.0.0.0", port: 8550, &entrypoint)
        @host = host
        @port = port
        @entrypoint = entrypoint
      end

      def run
        raise ArgumentError, "Ruflet::Rack.run requires a block" unless @entrypoint.respond_to?(:call)

        Ruflet.run(host: @host, port: @port) do |page|
          env = Context.current_env
          if @entrypoint.arity == 1
            @entrypoint.call(page)
          else
            @entrypoint.call(page, env)
          end
        end
      end
    end
  end
end
