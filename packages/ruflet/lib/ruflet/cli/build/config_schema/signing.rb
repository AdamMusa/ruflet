# frozen_string_literal: true

require_relative "sections"

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by NativeConfig::ApplePbxproj#ios_signing_team, before
        # RUFLET_IOS_TEAM_ID. Android release signing comes from
        # android/key.properties or RUFLET_ANDROID_*, not from ruflet.yaml.
        # Contributors::Signing applies it on ios, ipa and macos builds, and
        # always to ios/Runner.xcodeproj, so a macOS build sets the iOS
        # project's team too.
        register_platform("team_id", platforms: %w[ios], type: :string, feature: :signing,
          description: "Apple development team written into the iOS Xcode project. " \
            "`ruflet build macos` writes it there too.")
        register("app.ios_team_id", type: :string, feature: :signing, files: FILES,
          description: "Fallback for `ios.team_id`.")
        register("app.team_id", type: :string, feature: :signing, files: FILES,
          description: "Fallback for `ios.team_id`.")
      end
    end
  end
end
