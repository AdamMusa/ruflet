# frozen_string_literal: true

# Every invocation the published docs show, and the goldens that pin it.
#
# The forms are what `compat.rb docs-check` extracts from AdamMusa/ruflet_site
# content/docs at DOCS_COMMIT (fenced shell blocks and inline code spans that
# start with `ruflet`, `rake ruflet:`, `rails ruflet:` or `rails generate
# ruflet`). compat_goldens_test.rb checks that every golden listed here
# exists; `docs-check` checks that every documented form is listed. When the
# docs change, run docs-check against them and add what it reports.
module RufletCompat
  module DocsCoverage
    DOCS_COMMIT = "05dde18"

    BUILD_TARGETS = %w[apk android ios aab web macos windows linux].freeze

    INVOCATIONS = {
      # --- Rails (rails_integration.md, rails_api_reference.md, extensions.md)
      "rails generate ruflet:install" => %w[rails_new_app/generate-ruflet_install rails_app/generate-ruflet_install],
      "rails generate ruflet:install [--web] [--desktop]" => %w[
        rails_new_app/generate-ruflet_install--web rails_new_app/generate-ruflet_install--desktop
        rails_new_app/generate-ruflet_install--web--desktop rails_new_app/generate-ruflet_install--desktop-release
      ],
      "rake ruflet:build[aab]" => %w[rails_app/rake-ruflet_build_aab],
      "rake ruflet:build[apk]" => %w[rails_app/rake-ruflet_build_apk rails_app/rake-ruflet_build_apk-initializer-without-build-metadata],
      "rake ruflet:build[apk|android|ios|aab|desktop|macos|windows|linux]" =>
        %w[apk android ios aab desktop macos windows linux].map { |target| "rails_app/rake-ruflet_build_#{target}" },
      "rake ruflet:build[ios]" => %w[rails_app/rake-ruflet_build_ios],
      "rake ruflet:build[linux]" => %w[rails_app/rake-ruflet_build_linux],
      "rake ruflet:build[macos]" => %w[rails_app/rake-ruflet_build_macos],
      "rake ruflet:build[windows]" => %w[rails_app/rake-ruflet_build_windows],
      "rake ruflet:install[DEVICE_ID]" => %w[
        rails_app/rake-ruflet_install_emulator-5554 rails_app/rake-ruflet-install-without-device
        rails_app/rake-ruflet-install-without-device-after-ios
      ],
      "rake ruflet:update[desktop|all]" => %w[rails_app/rake-ruflet_update_desktop rails_app/rake-ruflet_update_all],
      # Documented, but the Railtie defines no ruflet:web task: the golden pins
      # rake's "Don't know how to build task".
      "rake ruflet:web" => %w[rails_app/rake-ruflet_web],

      # --- cli_reference.md and the guides --------------------------------------
      "ruflet" => %w[empty/no-arguments],
      "ruflet --help" => %w[empty/--help],
      "ruflet --version" => %w[empty/--version],
      "ruflet -v" => %w[empty/-v],
      "ruflet <command> [arguments] [options]" => %w[empty/help empty/bogus-command],
      "ruflet bootstrap <appname>" => %w[empty/bootstrap-my_app],
      "ruflet build" => %w[default_app/build-without-target],
      "ruflet build <apk|android|ios|aab|web|macos|windows|linux>" =>
        BUILD_TARGETS.map { |target| "default_app/build-#{target}" },
      "ruflet build <apk|android|ios|aab|web|macos|windows|linux> [--self] [--verbose]" =>
        BUILD_TARGETS.map { |target| "default_app/build-#{target}--self" } +
          %w[default_app/build-ios--self--verbose services_app/build-apk--verbose],
      "ruflet build aab" => %w[default_app/build-aab services_app/build-aab],
      "ruflet build android" => %w[default_app/build-android services_app/build-android],
      "ruflet build android --self" => %w[default_app/build-android--self services_app/build-android--self],
      "ruflet build apk" => %w[default_app/build-apk services_app/build-apk],
      "ruflet build ios" => %w[default_app/build-ios services_app/build-ios],
      "ruflet build ios --self" => %w[default_app/build-ios--self services_app/build-ios--self],
      "ruflet build ipa" => %w[default_app/build-ipa services_app/build-ipa],
      "ruflet build ipa --self" => %w[default_app/build-ipa--self services_app/build-ipa--self],
      "ruflet build linux" => %w[default_app/build-linux services_app/build-linux],
      "ruflet build macos" => %w[default_app/build-macos services_app/build-macos],
      "ruflet build web" => %w[default_app/build-web services_app/build-web],
      "ruflet build web --self" => %w[default_app/build-web--self],
      "ruflet build windows" => %w[default_app/build-windows services_app/build-windows],
      "ruflet create <appname>" => %w[empty/create-my_app],
      "ruflet create my_app" => %w[empty/create-my_app],
      "ruflet debug" => %w[default_app/debug default_app/debug-without-client],
      "ruflet debug --device-id chrome" => %w[default_app/debug--device-id-chrome],
      "ruflet debug [platform] [--device-id ID]" => %w[
        default_app/debug-web default_app/debug-ios default_app/debug-android--device-id-emulator-5554--release--v
      ],
      "ruflet debug [platform] [--platform NAME] [--device-id ID]" => %w[
        default_app/debug--platform-macos--web-renderer-canvaskit default_app/debug-android--device-id-emulator-5554--release--v
      ],
      "ruflet debug ios" => %w[default_app/debug-ios],
      "ruflet debug web" => %w[default_app/debug-web],
      "ruflet devices" => %w[default_app/devices],
      "ruflet devices [Flutter device options]" => %w[default_app/devices--machine],
      "ruflet doctor" => %w[default_app/doctor],
      "ruflet doctor --fix" => %w[default_app/doctor--fix],
      "ruflet doctor [--fix] [--verbose]" => %w[default_app/doctor--verbose default_app/doctor--fix--verbose],
      "ruflet doctor [--fix] [-v|--verbose]" => %w[default_app/doctor--v default_app/doctor--verbose default_app/doctor--fix--verbose],
      "ruflet emulators" => %w[default_app/emulators],
      "ruflet emulators --start --emulator ID" => %w[default_app/emulators--start--emulator-Pixel_8_API_35],
      "ruflet emulators --start --emulator ID [-v|--verbose]" => %w[
        default_app/emulators--start--emulator-Pixel_8_API_35--v default_app/emulators--start--emulator-Pixel_8_API_35--verbose
      ],
      "ruflet emulators [-v|--verbose]" => %w[default_app/emulators--v default_app/emulators--verbose],
      "ruflet help" => %w[empty/help],
      "ruflet init <appname>" => %w[empty/init-my_app],
      "ruflet install" => %w[default_app/install-without-build default_app/install-after-ios--self],
      "ruflet install --device DEVICE_ID" => %w[default_app/install--device-00008110-000A1C3A0E38801E--v],
      "ruflet install --device emulator-5554" => %w[default_app/install--device-emulator-5554],
      "ruflet install [--device DEVICE_ID] [--verbose]" => %w[
        default_app/install--verbose-after-ios--self default_app/install--device-emulator-5554--verbose
      ],
      "ruflet install [-d|--device DEVICE_ID] [-v|--verbose]" => %w[
        default_app/install--d-9FE7A9DF-85B7-4F12-91DB-0868ECEC72B8 default_app/install--device-00008110-000A1C3A0E38801E--v
        default_app/install--verbose-after-ios--self
      ],
      "ruflet new" => %w[empty/new],
      "ruflet new <appname>" => %w[empty/new-my_app],
      "ruflet new example_app" => %w[empty/new-my_app],
      "ruflet new my_app" => %w[empty/new-my_app],
      "ruflet run" => %w[default_app/run],
      "ruflet run --desktop" => %w[default_app/run--desktop],
      "ruflet run [scriptname|path] [--web|--desktop] [--port PORT] [--no-reload]" => %w[
        default_app/run-main.rb--web default_app/run-main.rb--desktop default_app/run-main.rb--port-9000
        default_app/run-main.rb--no-reload
      ],
      "ruflet run [script|path] [--web|--desktop] [--port PORT] [--no-reload]" => %w[
        default_app/run-main.rb--web default_app/run-main.rb--desktop default_app/run-main.rb--port-9000
        default_app/run-main.rb--no-reload
      ],
      "ruflet run apps/admin.rb --desktop --port 9000" => %w[default_app/run-apps_admin.rb--desktop--port-9000],
      "ruflet run main" => %w[default_app/run-main],
      "ruflet run main.rb" => %w[default_app/run-main.rb],
      "ruflet run main.rb --desktop" => %w[default_app/run-main.rb--desktop default_app/run-main.rb--desktop-release],
      "ruflet run main.rb --no-reload" => %w[default_app/run-main.rb--no-reload],
      "ruflet run main.rb --port 9000" => %w[default_app/run-main.rb--port-9000],
      "ruflet run main.rb --web" => %w[default_app/run-main.rb--web default_app/run-main.rb--web-offline default_app/run-main.rb--web-release],
      "ruflet run path/to/app.rb" => %w[default_app/run-apps_admin.rb--desktop--port-9000],
      "ruflet update" => %w[default_app/update default_app/update-release],
      "ruflet update [web|desktop|all] [--check] [--force]" => %w[
        default_app/update--check default_app/update-web--check default_app/update-all--force
        default_app/update-all--force-release-seeded
      ],
      "ruflet update [web|desktop|all] [--check] [--force] [--platform PLATFORM]" => %w[
        default_app/update-all--check--platform-linux default_app/update-desktop--platform-linux-release
        default_app/update-desktop--platform-windows-release
      ],
      "ruflet update all" => %w[default_app/update-all default_app/update-all-release],
      "ruflet update all --force" => %w[default_app/update-all--force default_app/update-all--force-release-seeded],
      "ruflet update desktop" => %w[default_app/update-desktop default_app/update-desktop-release],
      "ruflet update desktop --platform macos" => %w[default_app/update-desktop--platform-macos default_app/update-desktop--platform-macos-release],
      "ruflet update web --check" => %w[default_app/update-web--check default_app/update-web--check-seeded default_app/update-web--check-after-update],
      "ruflet version" => %w[empty/version]
    }.freeze

    # configuration_reference.md "Environment variables", and the ruflet.yml
    # fallback it describes.
    ENVIRONMENT = {
      "RUFLET_CONFIG" => %w[default_app/build-apk-with-RUFLET_CONFIG rails_app/rake-ruflet_build_apk],
      "ruflet.yml" => %w[default_app/build-apk-with-ruflet.yml],
      "RUFLET_PORT" => %w[default_app/run-main.rb-with-RUFLET_PORT],
      "RUFLET_CLIENT_DIR" => %w[
        default_app/build-apk--self-with-RUFLET_CLIENT_DIR default_app/build-apk--self-with-missing-RUFLET_CLIENT_DIR
        default_app/debug-web-with-RUFLET_CLIENT_DIR default_app/run-main.rb--web-with-RUFLET_CLIENT_DIR
      ],
      "RUFLET_FLUTTER_VERSION" => %w[
        default_app/build-apk--self-with-RUFLET_FLUTTER_VERSION default_app/build-apk--self-with-RUFLET_FLUTTER_VERSION-and-fvm
        default_app/doctor-with-RUFLET_FLUTTER_VERSION default_app/build-apk--self-with-fvmrc-and-fvm
      ]
    }.freeze

    # Documented, but not something the CLI goldens can pin.
    OUT_OF_SCOPE = {
      "RUFLET_HOST" => "read by the app's own server (Ruflet::App, Ruflet.run), never by the CLI; page goldens " \
                       "intercept Ruflet.run, so no server binds"
    }.freeze

    def self.golden_ids = (INVOCATIONS.values + ENVIRONMENT.values).flatten.uniq.sort
  end
end
