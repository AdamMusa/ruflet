# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by ConfigLoader#configured_backend_url, and by the Rails desktop
        # launcher. app.backend_url is the documented spelling.
        {
          "backend_url" => "Server a server-driven client connects to; required for mobile server-driven builds.",
          "server_url" => "Alias of `backend_url`.",
          "ruflet_client_url" => "Alias of `backend_url`."
        }.each do |key, description|
          register("app.#{key}", type: :url, feature: :backend, files: FILES, description: description)
          register(key, type: :url, feature: :backend, description: "Fallback for `app.#{key}`.")
        end
      end
    end
  end
end
