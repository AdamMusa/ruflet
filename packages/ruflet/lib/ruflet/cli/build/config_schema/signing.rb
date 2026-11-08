# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by NativeConfig::ApplePbxproj#ios_signing_team, before
        # RUFLET_IOS_TEAM_ID. Android release signing comes from
        # android/key.properties or RUFLET_ANDROID_*, not from ruflet.yaml.
        register_platform("team_id", platforms: %w[ios], type: :string, feature: :signing,
          description: "Apple development team for iOS builds.")
        register("app.ios_team_id", type: :string, feature: :signing, files: FILES,
          description: "Fallback for `ios.team_id`.")
        register("app.team_id", type: :string, feature: :signing, files: FILES,
          description: "Fallback for `ios.team_id`.")
      end
    end
  end
end
