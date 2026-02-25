# frozen_string_literal: true

module Ruflet
  module Rails
    module_function

    # Mount inside Rails routes; route "at:" controls URL path.
    # No host/port/path options are exposed at Rails API level.
    def endpoint(&block)
      Ruflet::RailsProtocol::Runner.new(&block).build_endpoint
    end

    # Load app/mobile/main.rb (MyApp.new.run) and mount it in Rails routes.
    # Route "at:" controls URL path.
    def mobile(file_path)
      Ruflet::RailsProtocol::Runner.new.build_mobile_endpoint(file_path: file_path)
    end
  end
end
