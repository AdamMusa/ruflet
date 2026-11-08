# frozen_string_literal: true

module Ruflet
  module CLI
    module Build
      module Contributors
        # Applies the app's name, version and identifiers to every platform host.
        module AppIdentity
          private

          def sync_client_metadata(client_dir, config = {}, verbose: false)
            metadata = build_client_metadata(config, client_dir)
            apply_pubspec_metadata(client_dir, metadata)
            apply_android_metadata(client_dir, metadata)
            apply_ios_metadata(client_dir, metadata)
            apply_macos_metadata(client_dir, metadata)
            apply_web_metadata(client_dir, metadata)
            apply_windows_metadata(client_dir, metadata)
            apply_linux_metadata(client_dir, metadata)
            build_log(
              verbose,
              "app=#{metadata[:display_name]} package=#{metadata[:package_name]} org=#{metadata[:organization]} bundle=#{metadata[:bundle_identifier]}"
            )
            metadata
          end

          def build_client_metadata(config, client_dir)
            app = config["app"].is_a?(Hash) ? config["app"] : {}
            current_pubspec = load_client_pubspec(client_dir)
            current_name = current_pubspec["name"].to_s
            inferred_display_name = app["app_name"] || app["name"] || config["name"] || humanize_name(File.basename(Dir.pwd))
            configured_app_name = first_present(app["app_name"], app["display_name"], app["name"])
            package_source = first_present(app["package_name"], config["package_name"], configured_app_name)
            package_source = current_name if package_source.nil?
            package_name = normalize_package_name(package_source)
            display_name = first_present(app["app_name"], app["display_name"], app["name"], config["display_name"], config["name"], humanize_name(package_name))
            organization = normalize_bundle_prefix(
              first_present(app["org"], app["organization"], config["org"], config["organization"], "com.example")
            )
            bundle_identifier = normalize_bundle_identifier(
              first_present(app["bundle_identifier"], config["bundle_identifier"], "#{organization}.#{package_name}")
            )
            identity_errors = []
            named = first_present(app["name"], app["app_name"], app["display_name"])
            identity_errors << "app.name" if named.nil?
            identity_errors << "app.package_name" if app["package_name"].to_s.strip.empty?
            identity_errors << "app.organization" if first_present(app["organization"], app["org"]).nil?

            {
              package_name: package_name,
              display_name: display_name,
              description: first_present(app["description"], config["description"], current_pubspec["description"], "A new Flutter project."),
              version: first_present(app["version"], config["version"], current_pubspec["version"], "1.0.0+1"),
              organization: organization,
              company_name: first_present(app["company_name"], config["company_name"], organization),
              bundle_identifier: bundle_identifier,
              android_application_id: normalize_bundle_identifier(
                first_present(app["android_application_id"], config["android_application_id"], bundle_identifier)
              ),
              ios_bundle_identifier: normalize_apple_bundle_identifier(
                first_present(app["ios_bundle_identifier"], config["ios_bundle_identifier"], bundle_identifier)
              ),
              macos_bundle_identifier: normalize_apple_bundle_identifier(
                first_present(app["macos_bundle_identifier"], config["macos_bundle_identifier"], bundle_identifier)
              ),
              linux_application_id: normalize_bundle_identifier(
                first_present(app["linux_application_id"], config["linux_application_id"], bundle_identifier)
              ),
              short_name: first_present(app["short_name"], config["short_name"], display_name),
              mobile_identity_errors: identity_errors.uniq
            }
          end

          def validate_mobile_app_identity(metadata, platform:)
            return true unless %w[apk android aab ios].include?(platform.to_s)
            return true unless metadata

            errors = Array(metadata[:mobile_identity_errors])
            return true if errors.empty?

            warn "build config error: ruflet.yaml must define #{errors.join(', ')}"
            warn "A mobile build needs app.name, app.package_name and app.organization."
            false
          end

          def load_client_pubspec(client_dir)
            pubspec_path = File.join(client_dir, "pubspec.yaml")
            return {} unless File.file?(pubspec_path)

            YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
          rescue StandardError
            {}
          end

          def apply_pubspec_metadata(client_dir, metadata)
            pubspec_path = File.join(client_dir, "pubspec.yaml")
            return unless File.file?(pubspec_path)

            data = YAML.safe_load(read_text_file(pubspec_path), aliases: true) || {}
            data["name"] = metadata[:package_name]
            data["description"] = metadata[:description]
            data["version"] = metadata[:version]
            write_pubspec_yaml(pubspec_path, data)
          end

          def apply_android_metadata(client_dir, metadata)
            manifest_path = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
            replace_in_file(
              manifest_path,
              /android:label="[^"]*"/,
              %(android:label="#{xml_escape(metadata[:display_name])}")
            )
          end

          def apply_ios_metadata(client_dir, metadata)
            info_plist_path = File.join(client_dir, "ios", "Runner", "Info.plist")
            replace_plist_value(info_plist_path, "CFBundleDisplayName", metadata[:display_name])
            replace_plist_value(info_plist_path, "CFBundleName", metadata[:display_name])

            pbxproj_path = File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")
            return unless File.file?(pbxproj_path)

            content = read_text_file(pbxproj_path)
            content.gsub!(/INFOPLIST_KEY_CFBundleDisplayName = "[^"]*";/, %(INFOPLIST_KEY_CFBundleDisplayName = "#{xcode_escape(metadata[:display_name])}";))
            write_text_file(pbxproj_path, content)
          end

          def apply_mobile_package_name(client_dir, metadata, platform:, tools:, verbose: false)
            return true unless metadata

            package_name, platform_flag = case platform.to_s
            when "apk", "android", "aab"
              [metadata[:android_application_id], "--android"]
            when "ios"
              [metadata[:ios_bundle_identifier], "--ios"]
            else
              return true
            end

            build_note("Applying #{platform_flag.delete_prefix('--')} package name #{package_name}")
            build_log(verbose, "running change_app_package_name for #{package_name} #{platform_flag}")
            ok = run_external_command(
              tools[:env],
              tools[:dart],
              "run",
              "change_app_package_name:main",
              package_name,
              platform_flag,
              chdir: client_dir,
              unbundled: true
            )
            warn "change_app_package_name failed for #{package_name}" unless ok
            ok
          end

          def apply_macos_metadata(client_dir, metadata)
            app_info_path = File.join(client_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig")
            replace_in_file(
              app_info_path,
              /^PRODUCT_NAME = .*$/,
              "PRODUCT_NAME = #{metadata[:display_name]}"
            )
            replace_in_file(
              app_info_path,
              /^PRODUCT_BUNDLE_IDENTIFIER = .*$/,
              "PRODUCT_BUNDLE_IDENTIFIER = #{metadata[:macos_bundle_identifier]}"
            )
            replace_in_file(
              app_info_path,
              /^PRODUCT_COPYRIGHT = .*$/,
              "PRODUCT_COPYRIGHT = Copyright © #{Time.now.year} #{metadata[:company_name]}. All rights reserved."
            )
          end

          def apply_web_metadata(client_dir, metadata)
            manifest_path = File.join(client_dir, "web", "manifest.json")
            if File.file?(manifest_path)
              data = JSON.parse(read_text_file(manifest_path))
              data["name"] = metadata[:display_name]
              data["short_name"] = metadata[:short_name]
              data["description"] = metadata[:description]
              write_text_file(manifest_path, JSON.pretty_generate(data) + "\n")
            end

            index_path = File.join(client_dir, "web", "index.html")
            replace_in_file(
              index_path,
              /<meta name="description" content="[^"]*">/,
              %(<meta name="description" content="#{html_escape(metadata[:description])}">)
            )
            replace_in_file(
              index_path,
              /<meta name="apple-mobile-web-app-title" content="[^"]*">/,
              %(<meta name="apple-mobile-web-app-title" content="#{html_escape(metadata[:short_name])}">)
            )
            replace_in_file(
              index_path,
              /<title>.*<\/title>/,
              "<title>#{html_escape(metadata[:display_name])}</title>"
            )
          end

          def apply_windows_metadata(client_dir, metadata)
            cmake_path = File.join(client_dir, "windows", "CMakeLists.txt")
            replace_in_file(cmake_path, /^project\(.*\)$/, "project(#{metadata[:package_name]} LANGUAGES CXX)")
            replace_in_file(cmake_path, /^set\(BINARY_NAME ".*"\)$/, %(set(BINARY_NAME "#{metadata[:package_name]}")))

            runner_rc_path = File.join(client_dir, "windows", "runner", "Runner.rc")
            replace_in_file(
              runner_rc_path,
              /VALUE "CompanyName", ".*" "\\0"/,
              %(VALUE "CompanyName", "#{windows_string_escape(metadata[:company_name])}" "\\0")
            )
            replace_in_file(
              runner_rc_path,
              /VALUE "FileDescription", ".*" "\\0"/,
              %(VALUE "FileDescription", "#{windows_string_escape(metadata[:display_name])}" "\\0")
            )
            replace_in_file(
              runner_rc_path,
              /VALUE "InternalName", ".*" "\\0"/,
              %(VALUE "InternalName", "#{windows_string_escape(metadata[:package_name])}" "\\0")
            )
            replace_in_file(
              runner_rc_path,
              /VALUE "LegalCopyright", ".*" "\\0"/,
              %(VALUE "LegalCopyright", "Copyright (C) #{Time.now.year} #{windows_string_escape(metadata[:company_name])}. All rights reserved." "\\0")
            )
            replace_in_file(
              runner_rc_path,
              /VALUE "OriginalFilename", ".*" "\\0"/,
              %(VALUE "OriginalFilename", "#{windows_string_escape(metadata[:package_name])}.exe" "\\0")
            )
            replace_in_file(
              runner_rc_path,
              /VALUE "ProductName", ".*" "\\0"/,
              %(VALUE "ProductName", "#{windows_string_escape(metadata[:display_name])}" "\\0")
            )
          end

          def apply_linux_metadata(client_dir, metadata)
            cmake_path = File.join(client_dir, "linux", "CMakeLists.txt")
            replace_in_file(cmake_path, /^set\(BINARY_NAME ".*"\)$/, %(set(BINARY_NAME "#{metadata[:package_name]}")))
            replace_in_file(cmake_path, /^set\(APPLICATION_ID ".*"\)$/, %(set(APPLICATION_ID "#{metadata[:linux_application_id]}")))
          end

          def normalize_package_name(value)
            normalized = value.to_s.strip.downcase.gsub(/[^a-z0-9_]+/, "_")
            normalized.gsub!(/\A_+|_+\z/, "")
            normalized.gsub!(/_+/, "_")
            normalized = "ruflet_client" if normalized.empty?
            normalized = "app_#{normalized}" if normalized.match?(/\A\d/)
            normalized
          end

          def normalize_bundle_prefix(value)
            segments = value.to_s.strip.downcase.split(".").map do |segment|
              normalized = segment.gsub(/[^a-z0-9_]+/, "")
              normalized = "app" if normalized.empty?
              normalized = "app#{normalized}" if normalized.match?(/\A\d/)
              normalized
            end
            segments.reject!(&:empty?)
            segments = %w[com example] if segments.empty?
            segments.join(".")
          end

          def normalize_bundle_identifier(value)
            segments = value.to_s.strip.downcase.split(".").map do |segment|
              normalized = segment.gsub(/[^a-z0-9_]+/, "_")
              normalized.gsub!(/\A_+|_+\z/, "")
              normalized = "app" if normalized.empty?
              normalized = "app#{normalized}" if normalized.match?(/\A\d/)
              normalized
            end
            segments.reject!(&:empty?)
            segments = %w[com example ruflet_client] if segments.empty?
            segments.join(".")
          end

          def normalize_apple_bundle_identifier(value)
            segments = value.to_s.strip.downcase.split(".").map do |segment|
              normalized = segment.gsub(/[^a-z0-9-]+/, "-")
              normalized.gsub!(/\A-+|-+\z/, "")
              normalized.gsub!(/-+/, "-")
              normalized = "app" if normalized.empty?
              normalized = "app-#{normalized}" if normalized.match?(/\A\d/)
              normalized
            end
            segments.reject!(&:empty?)
            segments = %w[com example app] if segments.empty?
            segments.join(".")
          end

          def humanize_name(name)
            name.to_s.gsub(/[_-]+/, " ").split.map(&:capitalize).join(" ")
          end
        end
      end
    end
  end
end
