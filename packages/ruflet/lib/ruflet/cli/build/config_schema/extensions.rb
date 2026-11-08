# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by Contributors::Extensions. Each item is a bundled extension
        # name, or a one-key map from an external package name to its `git`
        # (url, ref/branch/tag, path) or `path` source.
        register("extensions", type: :list, feature: :extensions,
          description: "Flutter client extensions to bundle.")
      end
    end
  end
end
