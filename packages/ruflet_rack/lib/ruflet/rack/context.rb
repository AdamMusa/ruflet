# frozen_string_literal: true

module Ruflet
  module Rack
    module Context
      THREAD_KEY = :ruflet_rack_env

      module_function

      def current_env
        Thread.current[THREAD_KEY]
      end

      def with_env(env)
        previous = Thread.current[THREAD_KEY]
        Thread.current[THREAD_KEY] = env
        yield
      ensure
        Thread.current[THREAD_KEY] = previous
      end
    end
  end
end
