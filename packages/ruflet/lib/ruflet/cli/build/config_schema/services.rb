# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by Contributors::ProtectedServices. services.yaml's list replaces
        # ruflet.yaml's. Each item is a service name, or a one-key map from the
        # name to its usage description (a string, or `{description: ...}`).
        register("services", type: :list, feature: :protected_services, files: FILES,
          description: "Protected device services: camera, microphone, location, motion, biometrics, photo_library.")
      end
    end
  end
end
