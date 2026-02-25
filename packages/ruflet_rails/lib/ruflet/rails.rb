# frozen_string_literal: true

module Ruflet
  module Rails
    module_function

    # Mount inside Rails routes; route "at:" controls URL path.
    def endpoint(&block)
      Protocol::Runner.new(&block).build_endpoint
    end

    # Load app/mobile/main.rb (MyApp.new.run) and mount it in Rails routes.
    def mobile(file_path)
      Protocol::Runner.new.build_mobile_endpoint(file_path: file_path)
    end
  end
end
