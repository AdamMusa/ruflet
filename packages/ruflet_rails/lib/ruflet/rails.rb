# frozen_string_literal: true

module Ruflet
  module Rails
    module_function

    def sessions
      @sessions ||= SessionRegistry.new
    end

    def broadcast(&block)
      sessions.broadcast(&block)
    end

    # Mount inside Rails routes; route "at:" controls URL path.
    def endpoint(&block)
      Protocol::Runner.new(&block).build_endpoint
    end

    # Load a Ruflet app file (MyApp.new.run) and mount it in Rails routes.
    def app(file_path)
      Protocol::Runner.new.build_app_endpoint(file_path: file_path)
    end

    # Backward-compatible alias for older Rails installs.
    def mobile(file_path)
      app(file_path)
    end
  end
end
