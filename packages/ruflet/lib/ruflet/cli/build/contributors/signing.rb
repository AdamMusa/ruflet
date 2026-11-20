# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Applies the project's signing: Android release keys (Gradle's
        # key.properties) and the Apple development team (project.pbxproj).
        module Signing
          private

          def contribute_signing(build)
            apply_android_signing_config(build.client_dir, build.platform, verbose: !!build.verbose)
            apply_ios_signing_team(build.client_dir, build.config) if %w[ios ipa macos].include?(build.platform.to_s)
            true
          end
        end

        register :signing, :contribute_signing
      end
    end
  end
end
