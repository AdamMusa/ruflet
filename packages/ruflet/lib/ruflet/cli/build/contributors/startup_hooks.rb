# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Writes the startup hooks this build's features add and points the
        # entrypoints at them (Ruflet::CLI::ClientBootstrap, WP-00 R3). While no
        # build feature adds a hook, it writes nothing. It runs once the
        # extension selection is applied and verified, so a hook can depend on
        # the extensions this build selected.
        module StartupHooks
          private

          def contribute_startup_hooks(build)
            write_client_bootstrap(
              build.client_dir, build.config,
              platform: build.platform, self_contained: build.self_contained)
            true
          end
        end

        register :startup_hooks, :contribute_startup_hooks, after: :extensions
      end
    end
  end
end
