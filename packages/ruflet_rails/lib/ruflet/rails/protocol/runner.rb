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

        def build_app_endpoint(file_path:, path: "/")
          absolute = File.expand_path(file_path)
          entrypoint = lambda do |page, env|
            loaded = MobileLoader.new(absolute).load!
            run_entrypoint(loaded[:entrypoint], page, env)
          end

          Endpoint.new(
            server: build_server(entrypoint, view_root: File.dirname(absolute)),
            path: path
          )
        end
        alias build_mobile_endpoint build_app_endpoint

        private

        def build_server(entrypoint, view_root: nil)
          LocalServer.new(view_root: view_root) do |page|
            env = Context.current_env
            run_entrypoint(entrypoint, page, env)
          end
        end

        def run_entrypoint(entrypoint, page, env)
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
