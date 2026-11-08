# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module ConfigSchema
        # Read by Contributors::AppIdentity#build_client_metadata. The app keys
        # may also come from services.yaml, whose `app` fills what ruflet.yaml
        # leaves out.
        {
          "app_name" => "User-facing app name; preferred over `name` for the display name.",
          "name" => "The app name.",
          "display_name" => "User-facing app name.",
          "package_name" => "Package-safe app name; required for mobile builds.",
          "organization" => "Reverse-domain organization; required for mobile builds.",
          "org" => "Alias of `organization`.",
          "bundle_identifier" => "Shared bundle id; defaults to organization.package_name.",
          "description" => "Package description.",
          "version" => "Release version and build number, e.g. 1.0.0+1.",
          "company_name" => "Company shown in desktop metadata; defaults to the organization.",
          "android_application_id" => "Android application id; defaults to bundle_identifier.",
          "ios_bundle_identifier" => "iOS bundle id; defaults to bundle_identifier.",
          "macos_bundle_identifier" => "macOS bundle id; defaults to bundle_identifier.",
          "linux_application_id" => "Linux application id; defaults to bundle_identifier.",
          "short_name" => "Shorter display name (web manifest); defaults to the display name."
        }.each do |key, description|
          register("app.#{key}", type: :string, feature: :app_identity, files: FILES, description: description)
          # Older projects state the identity at the document root.
          next if key == "app_name"

          register(key, type: :string, feature: :app_identity, description: "Fallback for `app.#{key}`.")
        end
      end
    end
  end
end
