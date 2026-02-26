# frozen_string_literal: true

module Ruflet
  module Rails
    module Protocol
      class Middleware
        def initialize(app)
          @app = app
        end

        def call(env)
          Context.with_env(env) { @app.call(env) }
        end
      end
    end
  end
end
