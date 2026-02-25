# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      class Runner
        def initialize(&entrypoint)
          @entrypoint = entrypoint
        end

        def build_endpoint(path: "/")
          raise ArgumentError, "Ruflet::Rails::Protocol endpoint requires a block" unless @entrypoint.respond_to?(:call)

          Endpoint.new(server: build_server(@entrypoint), path: path)
        end

        def build_mobile_endpoint(file_path:, path: "/")
          loaded = MobileLoader.new(file_path).load!
          Endpoint.new(server: build_server(loaded[:entrypoint]), path: path)
        end

        private

        def build_server(entrypoint)
          Ruflet::Server.new do |page|
            env = Context.current_env
            if entrypoint.arity == 1
              entrypoint.call(page)
            else
              entrypoint.call(page, env)
            end
          end
        end
      end
    end
  end
end
