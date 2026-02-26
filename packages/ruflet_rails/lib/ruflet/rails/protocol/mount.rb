# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      class Mount
        def initialize(app, file_path:, path: "/ws")
          @app = app
          @path = path
          @endpoint = Runner.new.build_mobile_endpoint(file_path: file_path, path: "/")
        end

        def call(env)
          return @app.call(env) unless env["PATH_INFO"] == @path

          mounted_env = env.dup
          mounted_env["PATH_INFO"] = "/"
          @endpoint.call(mounted_env)
        end
      end
    end
  end
end
