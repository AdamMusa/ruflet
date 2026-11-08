# frozen_string_literal: true

# The compatibility corpus: which projects the goldens are taken from and which
# `ruflet` invocations run against them. Pure data, read by lib/harness.rb.
#
# Every invocation documented in the published docs (AdamMusa/ruflet_site
# content/docs at 05dde18: cli_reference.md, the other guides, and the Rails
# guides' rake tasks and generator) appears here at least once, so a change to
# any of them shows up as a golden diff. Add new invocations at the end of a
# section; never change an existing entry's argv, or its golden stops proving
# anything.
#
# Entry options: `id:` names the golden; `env:` adds environment variables
# (`<PROJECT>` and `<SANDBOX>` expand to the sandbox paths); `files:` adds
# project files (nil removes one); `before:` runs `ruflet` steps first;
# `seed: "prebuilt_clients"` installs a current prebuilt client cache;
# `network: "release"` serves a fake GitHub release (lib/release_fixture.rb)
# instead of answering every request 503; `runtime: true` provides a local
# ruby_runtime; `template: "explicit"` sets RUFLET_TEMPLATE_ROOT;
# `client_copy: true` copies the template to <SANDBOX>/client; `host_fvm:
# true` puts an (emulated) fvm on PATH; `rake: true`
# runs a Railtie task; `generator: true` runs a Rails generator.
module RufletCompat
  module Corpus
    # Projects. `generated` fixtures are produced by the CLI itself on every run
    # (so `ruflet new` and the builds of its output can never disagree); `dir`
    # fixtures are committed under fixtures/; `docs` fixtures are the default
    # app with main.rb replaced by a whole-app example from the docs.
    FIXTURES = {
      "empty" => { "kind" => "empty" },
      "default_app" => { "kind" => "generated", "argv" => %w[new default_app] },
      "services_app" => { "kind" => "dir", "path" => "fixtures/services_app" },
      "rails_app" => { "kind" => "dir", "path" => "fixtures/rails_app", "rails" => true },
      # A fresh `rails new` app before `rails generate ruflet:install`.
      "rails_new_app" => { "kind" => "dir", "path" => "fixtures/rails_new_app", "rails" => true }
    }

    # Whole-app examples from the published docs (AdamMusa/ruflet_site
    # content/docs, as extracted by the docs snippet harness). Each is committed
    # verbatim under fixtures/docs/<id>.rb with a provenance header.
    DOCS_APPS = %w[
      app_structure__1
      introduction__1
      control_qrcode_scanner__1
      tutorial_calculator__1
      rails_integration__2
    ].freeze
    # Rails view entrypoints from the docs; they only make sense inside a Rails
    # app, so they get page goldens but no build.
    DOCS_RAILS_APPS = %w[
      rails_native_html__3
      rails_webview_apps__1
      rails_api_reference__5
      rails_erb_to_native__1
    ].freeze

    (DOCS_APPS + DOCS_RAILS_APPS).each do |id|
      FIXTURES["docs_#{id}"] = { "kind" => "docs", "snippet" => "fixtures/docs/#{id}.rb", "base" => "default_app" }
    end
    FIXTURES.freeze

    FAKE_SIGNING_ENV = {
      # Obviously fake values: they only prove the CLI writes key.properties.
      "RUFLET_ANDROID_KEYSTORE" => "signing/compat-upload.keystore",
      "RUFLET_ANDROID_KEYSTORE_PASSWORD" => "compat-not-a-secret",
      "RUFLET_ANDROID_KEY_ALIAS" => "compat",
      "RUFLET_ANDROID_KEY_PASSWORD" => "compat-not-a-secret"
    }.freeze

    INVOCATIONS = []

    def self.cli(fixture, *argv, id: nil, **options)
      entry = { "fixture" => fixture, "argv" => argv }
      entry["id"] = id if id
      options.each { |key, value| entry[key.to_s] = value }
      INVOCATIONS << entry
    end

    # `rails generate ruflet:install ARGV` in a Rails app.
    def self.generate(fixture, *argv, **options)
      cli(fixture, "ruflet:install", *argv, generator: true, **options)
    end

    BUILD_TARGETS = %w[apk android aab ios ipa web macos windows linux].freeze

    # --- top level ------------------------------------------------------------
    cli "empty", id: "no-arguments"
    %w[--version -v version help --help -h].each { |flag| cli "empty", flag }
    cli "empty", "bogus-command"
    # Commands are matched case-insensitively. (Golden names differing only in
    # case would collide on macOS, hence the explicit ids.)
    cli "empty", "VERSION", id: "uppercase-command-VERSION"

    # --- create a project -----------------------------------------------------
    cli "empty", "new", "my_app"
    cli "empty", "create", "my_app"
    cli "empty", "bootstrap", "my_app"
    cli "empty", "init", "my_app"
    cli "empty", "new"
    cli "default_app", "new", "assets", id: "new-existing-directory"

    # --- build: every documented target, server-driven and self-contained -----
    BUILD_TARGETS.each do |target|
      cli "default_app", "build", target
      cli "default_app", "build", target, "--self"
    end
    cli "default_app", "build", id: "build-without-target"
    cli "default_app", "build", "bogus"
    cli "default_app", "build", "apk", "--lite"
    cli "default_app", "build", "apk", "--full"
    cli "default_app", "build", "apk", "--self", "--full"
    cli "default_app", "build", "apk", "--lite", "--full"
    cli "default_app", "build", "web", "--lite"
    cli "default_app", "build", "apk", "--self", "-v"
    cli "default_app", "build", "ios", "--self", "--verbose"
    cli "default_app", "build", "ios", "--self", "--simulator"
    cli "default_app", "build", "ios", "--self", "--no-codesign"
    cli "default_app", "build", "apk", "--self", "--release", "--split-per-abi"
    biometrics = {
      "services.yaml" => "app:\n  app_name: Default App\n  package_name: default_app\n  organization: com.example\n" \
                         "  version: 1.0.0+1\n  description: A new Ruflet app.\n\nservices:\n  - biometrics\n"
    }
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-biometrics", files: biometrics
    cli "default_app", "build", "ios", "--self", id: "build-ios--self-biometrics", files: biometrics
    cli "default_app", "build", "apk", "--self", id: "rebuild-apk--self", before: [%w[build apk --self]]
    cli "default_app", "build", "ios", "--self", id: "build-ios--self-after-apk", before: [%w[build apk --self]]
    # The target table beyond the documented names: `appbundle` is accepted
    # beside `aab`, and targets are matched case-insensitively.
    cli "default_app", "build", "appbundle", "--self"
    cli "default_app", "build", "APK", "--self", id: "build-uppercase-target-APK--self"

    # --- run ------------------------------------------------------------------
    run_files = { "apps/admin.rb" => "require \"ruflet\"\n\nRuflet.run { |page| page.add(text(\"Admin\")) }\n" }
    cli "default_app", "run"
    cli "default_app", "run", "main"
    cli "default_app", "run", "main.rb"
    cli "default_app", "run", "main.rb", "--web", seed: "prebuilt_clients"
    cli "default_app", "run", "main.rb", "--desktop", seed: "prebuilt_clients"
    cli "default_app", "run", "--desktop", seed: "prebuilt_clients"
    cli "default_app", "run", "apps/admin.rb", "--desktop", "--port", "9000", seed: "prebuilt_clients", files: run_files
    cli "default_app", "run", "main.rb", "--port", "9000"
    cli "default_app", "run", "main.rb", "--no-reload"
    cli "default_app", "run", "main.rb", "--web", id: "run-main.rb--web-offline"
    cli "default_app", "run", "missing.rb"
    cli "default_app", "run", "main.rb", "--port=9000"
    # RUFLET_PORT in the developer's environment (configuration_reference.md).
    cli "default_app", "run", "main.rb", id: "run-main.rb-with-RUFLET_PORT", env: { "RUFLET_PORT" => "9100" }
    # RUFLET_CLIENT_DIR names an existing client; its built web/ is served.
    cli "default_app", "run", "main.rb", "--web", id: "run-main.rb--web-with-RUFLET_CLIENT_DIR",
                                                  env: { "RUFLET_CLIENT_DIR" => "<PROJECT>/my_client" },
                                                  files: { "my_client/build/web/index.html" => "<!doctype html>\n",
                                                           "my_client/build/web/main.dart.js" => "// my client\n" }
    # Without a prebuilt cache, against a release to download from.
    cli "default_app", "run", "main.rb", "--web", id: "run-main.rb--web-release", network: "release"
    cli "default_app", "run", "main.rb", "--desktop", id: "run-main.rb--desktop-release", network: "release"

    # --- update ---------------------------------------------------------------
    cli "default_app", "update", "--check"
    cli "default_app", "update", "web", "--check"
    cli "default_app", "update", "all", "--check", "--platform", "linux"
    cli "default_app", "update", "web", "--check", id: "update-web--check-seeded", seed: "prebuilt_clients"
    cli "default_app", "update"
    cli "default_app", "update", "desktop"
    cli "default_app", "update", "desktop", "--platform", "macos"
    cli "default_app", "update", "all"
    cli "default_app", "update", "all", "--force"
    cli "default_app", "update", "bogus"
    # The same commands against a release to download from: download,
    # extract (the real tar/ditto), manifest, and the cache checks.
    cli "default_app", "update", id: "update-release", network: "release"
    cli "default_app", "update", "all", id: "update-all-release", network: "release"
    cli "default_app", "update", "all", "--force", id: "update-all--force-release-seeded", network: "release",
                                                  seed: "prebuilt_clients"
    cli "default_app", "update", "all", id: "update-all-release-seeded-current", network: "release", seed: "prebuilt_clients"
    cli "default_app", "update", "all", id: "update-all-release-seeded-due", network: "release", seed: "prebuilt_clients",
                                        env: { "RUFLET_CLIENT_UPDATE_INTERVAL" => "0" }
    cli "default_app", "update", "desktop", id: "update-desktop-release", network: "release"
    cli "default_app", "update", "desktop", "--platform", "macos", id: "update-desktop--platform-macos-release", network: "release"
    cli "default_app", "update", "desktop", "--platform", "linux", id: "update-desktop--platform-linux-release", network: "release"
    cli "default_app", "update", "desktop", "--platform=windows", id: "update-desktop--platform-windows-release", network: "release"
    cli "default_app", "update", "web", id: "update-web-release-stable-channel", network: "release",
                                        env: { "RUFLET_CLIENT_CHANNEL" => "stable" }
    cli "default_app", "update", "web", "--check", id: "update-web--check-after-update", network: "release",
                                                   before: [%w[update web]]

    # --- debug ----------------------------------------------------------------
    cli "default_app", "debug", id: "debug-without-client"
    cli "default_app", "debug", id: "debug", before: [%w[build web]]
    cli "default_app", "debug", "web", before: [%w[build web]]
    cli "default_app", "debug", "ios", before: [%w[build web]]
    cli "default_app", "debug", "--device-id", "chrome", before: [%w[build web]]
    cli "default_app", "debug", "android", "--device-id", "emulator-5554", "--release", "-v", before: [%w[build web]]
    cli "default_app", "debug", "--platform", "macos", "--web-renderer", "canvaskit", before: [%w[build web]]
    cli "default_app", "debug", "web", "--verbose", before: [%w[build web]]
    # RUFLET_CLIENT_DIR selects the client for debug (configuration_reference.md),
    # and ./ruflet_client is the fallback after build/client.
    cli "default_app", "debug", "web", id: "debug-web-with-RUFLET_CLIENT_DIR",
                                       env: { "RUFLET_CLIENT_DIR" => "<PROJECT>/my_client" },
                                       files: { "my_client/pubspec.yaml" => "name: my_client\n" }
    cli "default_app", "debug", "web", id: "debug-web-with-ruflet_client-dir", files: { "ruflet_client/pubspec.yaml" => "name: ruflet_client\n" }

    # --- install --------------------------------------------------------------
    cli "default_app", "install", id: "install-without-build"
    cli "default_app", "install", id: "install-after-ios--self", before: [%w[build ios --self]]
    cli "default_app", "install", "--device", "00008110-000A1C3A0E38801E", "-v", before: [%w[build ios --self]]
    cli "default_app", "install", "-d", "9FE7A9DF-85B7-4F12-91DB-0868ECEC72B8", before: [%w[build ios --self]]
    cli "default_app", "install", "-d", "9FE7A9DF-85B7-4F12-91DB-0868ECEC72B8", id: "install-simulator-after-ios--self--no-codesign",
                                  before: [%w[build ios --self --no-codesign]]
    cli "default_app", "install", "--device", "emulator-5554", before: [%w[build apk --self]]
    cli "default_app", "install", "--verbose", id: "install--verbose-after-ios--self", before: [%w[build ios --self]]
    cli "default_app", "install", "--device", "emulator-5554", "--verbose", before: [%w[build apk --self]]
    cli "default_app", "install", "--device=emulator-5554", before: [%w[build apk --self]]

    # --- devices, emulators, doctor -------------------------------------------
    cli "default_app", "devices"
    cli "default_app", "devices", "--machine"
    cli "default_app", "emulators"
    cli "default_app", "emulators", "-v"
    cli "default_app", "emulators", "--start", "--emulator", "Pixel_8_API_35"
    cli "default_app", "emulators", "--start", "--emulator", "Pixel_8_API_35", "-v"
    cli "default_app", "emulators", "--start"
    cli "default_app", "emulators", "--create"
    cli "default_app", "doctor"
    cli "default_app", "doctor", "-v"
    cli "default_app", "doctor", "--fix"
    cli "default_app", "emulators", "--verbose"
    cli "default_app", "emulators", "--start", "--emulator", "Pixel_8_API_35", "--verbose"
    cli "default_app", "doctor", "--verbose"
    cli "default_app", "doctor", "--fix", "--verbose"
    cli "default_app", "doctor", id: "doctor-with-RUFLET_FLUTTER_VERSION", env: { "RUFLET_FLUTTER_VERSION" => "3.38.9" }

    # --- services/extensions-heavy project -------------------------------------
    BUILD_TARGETS.each do |target|
      cli "services_app", "build", target
      cli "services_app", "build", target, "--self" unless target == "web"
    end
    cli "services_app", "build", "apk", id: "build-apk-with-signing-env", env: FAKE_SIGNING_ENV
    cli "services_app", "build", "ios", "--self", id: "build-ios--self-with-team-env", env: { "RUFLET_IOS_TEAM_ID" => "ENVTEAM42" }
    cli "services_app", "build", "apk", "--self", id: "build-apk--self-local-runtime", runtime: true
    cli "services_app", "build", "ios", "--self", id: "build-ios--self-local-runtime", runtime: true
    cli "services_app", "build", "ios", "--self", "--simulator", id: "build-ios--self--simulator-local-runtime", runtime: true
    cli "services_app", "build", "apk", "--self", id: "build-apk--self-explicit-template", template: "explicit"
    cli "services_app", "build", "apk", id: "rebuild-apk-server-after-self", before: [%w[build apk --self]]
    cli "services_app", "build", "apk", id: "rebuild-apk-server", before: [%w[build apk]]
    cli "services_app", "build", "macos", "--self", id: "rebuild-macos--self-after-ios", before: [%w[build ios --self]]
    cli "services_app", "build", "apk", "--verbose"
    cli "services_app", "build", "appbundle"

    # --- Rails project: rake tasks and the plain CLI in Rails.root ------------
    cli "rails_app", "ruflet:build[apk]", rake: true
    cli "rails_app", "ruflet:build[ios]", rake: true
    cli "rails_app", "ruflet:build[desktop]", rake: true
    cli "rails_app", "ruflet:build[web]", rake: true
    cli "rails_app", "ruflet:build[]", id: "rake-ruflet-build-without-platform", rake: true
    cli "rails_app", "build", "apk"
    cli "rails_app", "build", "web"
    # Every target rails_api_reference.md lists for ruflet:build, plus case
    # and an unknown target.
    %w[aab android macos windows linux bogus].each { |target| cli "rails_app", "ruflet:build[#{target}]", rake: true }
    cli "rails_app", "ruflet:build[APK]", id: "rake-ruflet_build-uppercase-target-APK", rake: true
    # An initializer with no build metadata: the task builds from ruflet.yaml.
    cli "rails_app", "ruflet:build[apk]", id: "rake-ruflet_build_apk-initializer-without-build-metadata", rake: true,
                                          files: { "config/initializers/ruflet.rb" => "Ruflet::Rails.configure { |config| }\n" }
    cli "rails_app", "ruflet:install[emulator-5554]", rake: true, before: [%w[build apk]]
    cli "rails_app", "ruflet:install[]", id: "rake-ruflet-install-without-device", rake: true, before: [%w[build apk]]
    # Without a device, install looks for iOS outputs on a Mac.
    cli "rails_app", "ruflet:install[]", id: "rake-ruflet-install-without-device-after-ios", rake: true, before: [%w[build ios]]
    cli "rails_app", "ruflet:install[]", id: "rake-ruflet-install-without-build", rake: true
    # A current cache, so only the task's own argv decides whether it downloads.
    cli "rails_app", "ruflet:update[desktop]", rake: true, network: "release", seed: "prebuilt_clients"
    cli "rails_app", "ruflet:update[all]", rake: true, network: "release"
    cli "rails_app", "ruflet:update[]", id: "rake-ruflet-update-without-target", rake: true
    # Documented in rails_integration.md and rails_api_reference.md, but the
    # Railtie defines no such task.
    cli "rails_app", "ruflet:web", rake: true
    cli "rails_app", "--tasks", id: "rake--tasks", rake: true

    # --- `rails generate ruflet:install [--web] [--desktop]` -----------------
    # The generator declares --desktop and --client; Rails ignores --web.
    generate "rails_new_app"
    generate "rails_new_app", "--desktop"
    generate "rails_new_app", "--desktop", id: "generate-ruflet_install--desktop-release", network: "release"
    generate "rails_new_app", "--client", "desktop", network: "release"
    generate "rails_new_app", "--client", "none"
    generate "rails_new_app", "--client", "bogus"
    generate "rails_new_app", "--web"
    generate "rails_new_app", "--web", "--desktop"
    generate "rails_new_app", "--desktop", id: "generate-ruflet_install--desktop-shell-bin-dev",
                                           files: { "bin/dev" => "#!/usr/bin/env sh\n\nexec foreman start -f Procfile.dev \"$@\"\n" }
    generate "rails_app" # already installed: every step is skipped

    # --- documented environment variables (configuration_reference.md) -------
    # RUFLET_PORT, RUFLET_CLIENT_DIR (run, debug) and RUFLET_FLUTTER_VERSION
    # (doctor) are in their command sections above.
    alt_config = "app:\n  name: Alt App\n  package_name: alt_app\n  organization: com.compat.alt\n" \
                 "  backend_url: https://alt.example.com\n"
    cli "default_app", "build", "apk", id: "build-apk-with-RUFLET_CONFIG", env: { "RUFLET_CONFIG" => "config/alt.yaml" },
                                       files: { "config/alt.yaml" => alt_config }
    cli "default_app", "build", "apk", id: "build-apk-with-ruflet.yml", files: { "ruflet.yaml" => nil, "ruflet.yml" => alt_config }
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-with-RUFLET_FLUTTER_VERSION",
                                                 env: { "RUFLET_FLUTTER_VERSION" => "3.41.2" }
    # The same with FVM installed, and the project's .fvmrc it falls back to.
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-with-RUFLET_FLUTTER_VERSION-and-fvm", host_fvm: true,
                                                 env: { "RUFLET_FLUTTER_VERSION" => "3.41.2" }
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-with-fvmrc-and-fvm", host_fvm: true,
                                                 files: { ".fvmrc" => "{\"flutter\": \"3.38.9\"}\n" }
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-with-RUFLET_CLIENT_DIR", client_copy: true,
                                                 env: { "RUFLET_CLIENT_DIR" => "<SANDBOX>/client" }
    cli "default_app", "build", "apk", "--self", id: "build-apk--self-with-missing-RUFLET_CLIENT_DIR",
                                                 env: { "RUFLET_CLIENT_DIR" => "<PROJECT>/no_such_client" }
    # RUFLET_CONFIG also moves the directory config paths resolve against:
    # assets named in the config, and the services.yaml beside it.
    cli "default_app", "build", "apk", id: "build-apk-with-RUFLET_CONFIG-relative-assets-and-services",
                                       env: { "RUFLET_CONFIG" => "config/alt.yaml" },
                                       files: {
                                         "config/alt.yaml" => "#{alt_config}assets:\n  icon_launcher: assets/icon.png\n" \
                                                              "  splash_screen: assets/splash.png\n",
                                         "config/assets/icon.png" => "compat: the icon beside config/alt.yaml\n",
                                         "config/assets/splash.png" => "compat: the splash beside config/alt.yaml\n",
                                         "config/services.yaml" => "services:\n  - camera\n"
                                       }
    # RUFLET_IOS_TEAM_ID for an app that names no team (services_app's
    # ios.team_id wins over it), and what a macOS build does with it today
    # (it sets the iOS project's team; D6 adds an explicit macos.team_id).
    cli "default_app", "build", "ios", "--self", id: "build-ios--self-with-RUFLET_IOS_TEAM_ID",
                                                 env: { "RUFLET_IOS_TEAM_ID" => "ENVTEAM42" }
    cli "default_app", "build", "macos", "--self", id: "build-macos--self-with-RUFLET_IOS_TEAM_ID",
                                                   env: { "RUFLET_IOS_TEAM_ID" => "ENVTEAM42" }

    # --- docs example apps: the embedded (self-contained) project ------------
    DOCS_APPS.each { |id| cli "docs_#{id}", "build", "apk", "--self" }

    # --- flags whose meaning later work packages pin or fix (CLI-01/03/05/12) --
    # These record today's behavior, including today's failures, so a change
    # to any of them is visible and has to be approved as a behavior change.
    cli "default_app", "run", "main.rb", "-d", seed: "prebuilt_clients"
    cli "default_app", "run", "main.rb", "--device", "emulator-5554"
    cli "default_app", "run", "--bogus-flag"
    cli "default_app", "build", "--release", "apk"
    cli "default_app", "build", "apk", "--self", "--bogus-flag"
    cli "default_app", "build", "apk", "--self", "--split-debug-info=symbols", "--obfuscate"
    cli "default_app", "build", "apk", "--self", "--split-debug-info", "symbols"
    cli "default_app", "build", "web", "-o", "dist"
    cli "default_app", "build", "web", "--web-renderer", "html"
    cli "default_app", "help", "build"
    cli "default_app", "update", "--bogus-flag"
    cli "default_app", "debug", "--bogus-flag", before: [%w[build web]]
    cli "default_app", "install", "--bogus-flag", before: [%w[build apk --self]]
    cli "default_app", "devices", "--bogus-flag"
    cli "default_app", "emulators", "--cold"
    cli "default_app", "doctor", "--bogus-flag"
    cli "empty", "new", "my_app", "--bogus-flag"

    INVOCATIONS.freeze

    # Initial page patch goldens: what a client receives in reply to
    # register_client for each fixture app, from Ruflet::Server (`ruflet
    # run`). The `--rails-endpoint` entries run the Rails apps the way a Rails
    # server serves them, through the endpoint config/routes.rb mounts
    # (`Ruflet::Rails.native`): register_client without a page patch, then
    # the page as `page.update` op patches.
    rails_prelude = 'Ruflet::Rails.config.backend_url = "https://app.test"' # config/initializers/ruflet.rb
    PAGES = [
      { "fixture" => "default_app", "entrypoint" => "main.rb" },
      { "fixture" => "services_app", "entrypoint" => "main.rb" },
      { "fixture" => "rails_app", "entrypoint" => "app/views/ruflet/main.rb", "rails" => true },
      *DOCS_APPS.map { |id| { "fixture" => "docs_#{id}", "entrypoint" => "main.rb" } },
      *DOCS_RAILS_APPS.map do |id|
        { "fixture" => "docs_#{id}", "entrypoint" => "main.rb", "rails" => true, "prelude" => rails_prelude }
      end,
      { "fixture" => "rails_app", "id" => "rails_app--rails-endpoint", "mode" => "rails_endpoint",
        "entrypoint" => "app/views/ruflet/main.rb", "rails" => true },
      *DOCS_RAILS_APPS.map do |id|
        { "fixture" => "docs_#{id}", "id" => "docs_#{id}--rails-endpoint", "mode" => "rails_endpoint",
          "entrypoint" => "main.rb", "rails" => true, "prelude" => rails_prelude }
      end
    ].freeze
  end
end
