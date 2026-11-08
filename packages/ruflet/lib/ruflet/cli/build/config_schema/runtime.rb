# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by Contributors::RuntimeMode#configure_native_apple_runtime and
        # EmbeddedRuntime#configure_full_runtime_distribution.
        register_platform("local_network", platforms: %w[ios macos], type: :boolean, feature: :runtime_mode,
          description: "Declare local-network access (NSLocalNetworkUsageDescription, NSAllowsLocalNetworking).")
        register_platform("local_network_usage_description", platforms: %w[ios macos], type: :string,
          feature: :runtime_mode, description: "The local-network prompt text.")
        register("build.full_runtime_path", type: :path, feature: :runtime_mode,
          description: "CRuby runtime distribution for --full; RUFLET_FULL_RUNTIME_PATH wins.")
      end
    end
  end
end
