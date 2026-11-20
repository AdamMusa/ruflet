# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module NativeConfig
        # Writes the iOS and macOS Runner.xcodeproj/project.pbxproj.
        module ApplePbxproj
          private

          # The signing team belongs to whoever ships the app, so it comes from the
          # project rather than being baked into the client.
          def apply_ios_signing_team(client_dir, config)
            team = ios_signing_team(config)
            pbxproj_path = File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
            return unless File.file?(pbxproj_path)

            if team.to_s.strip.empty?
              build_note("No ios.team_id configured; Xcode will pick the signing team")
              replace_in_file(pbxproj_path, /DEVELOPMENT_TEAM = [^;]*;/, "DEVELOPMENT_TEAM = \"\";")
              return
            end

            replace_in_file(pbxproj_path, /DEVELOPMENT_TEAM = [^;]*;/, "DEVELOPMENT_TEAM = #{team};")
            build_note("iOS signing team set to #{team}")
          end

          def ios_signing_team(config)
            app = config["app"].is_a?(Hash) ? config["app"] : {}
            first_present(
              platform_build_config(config, "ios")["team_id"],
              app["ios_team_id"],
              app["team_id"],
              ENV["RUFLET_IOS_TEAM_ID"]
            )
          end

          def strip_native_apple_xcode_project(client_dir, platform)
            path = File.join(client_dir, platform, "Runner.xcodeproj", "project.pbxproj")
            return unless File.file?(path)

            content = read_text_file(path)
            content.gsub!(
              %r{^\s*[A-F0-9]+ /\* XCLocalSwiftPackageReference "\.\./apple_(?:extensions|packages/ruflet_apple)" \*/ = \{.*?^\s*\};\n}m,
              ""
            )
            content = content.lines.reject do |line|
              line.include?("Ruflet") ||
                line.include?("../apple_extensions") ||
                line.include?("../apple_packages/ruflet_apple")
            end.join
            write_text_file(path, content)
          end
        end
      end
    end
  end
end
