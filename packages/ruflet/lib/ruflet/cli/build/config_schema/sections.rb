# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # The sections the other features' keys sit in (ConfigLoader).
        register("app", type: :map, feature: :config, files: FILES,
          description: "The app's identity and backend. services.yaml may carry one too; ruflet.yaml wins.")
        register("build", type: :map, feature: :config,
          description: "Build options. Its asset keys are read before their `assets` counterparts.")
        register("assets", type: :map, feature: :config,
          description: "Splash screen and launcher icon images, relative to ruflet.yaml.")
        PLATFORMS.each do |platform|
          PLATFORM_SECTION_ROOTS.each do |root|
            register([root, platform].compact.join("."), type: :map, feature: :config,
              description: "#{platform} options; `#{platform}`, `build.#{platform}` and `assets.#{platform}` merge, later ones winning.")
          end
        end
      end
    end
  end
end
