# frozen_string_literal: true

# The compatibility corpus: which projects the goldens are taken from and which
# `ruflet` invocations run against them. Pure data, read by lib/harness.rb.
#
# Every CLI invocation documented in the docs (cli_reference.md first, then the
# other guides) appears here at least once, so a change to any of them shows up
# as a golden diff. Add new invocations at the end of a section; never change
# an existing entry's argv, or its golden stops proving anything.
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
      "rails_app" => { "kind" => "dir", "path" => "fixtures/rails_app", "rails" => true }
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

    BUILD_TARGETS = %w[apk android aab ios ipa web macos windows linux].freeze

    # --- top level ------------------------------------------------------------
    cli "empty", id: "no-arguments"
    %w[--version -v version help --help -h].each { |flag| cli "empty", flag }
    cli "empty", "bogus-command"

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

    # --- debug ----------------------------------------------------------------
    cli "default_app", "debug", id: "debug-without-client"
    cli "default_app", "debug", id: "debug", before: [%w[build web]]
    cli "default_app", "debug", "web", before: [%w[build web]]
    cli "default_app", "debug", "ios", before: [%w[build web]]
    cli "default_app", "debug", "--device-id", "chrome", before: [%w[build web]]
    cli "default_app", "debug", "android", "--device-id", "emulator-5554", "--release", "-v", before: [%w[build web]]
    cli "default_app", "debug", "--platform", "macos", "--web-renderer", "canvaskit", before: [%w[build web]]

    # --- install --------------------------------------------------------------
    cli "default_app", "install", id: "install-without-build"
    cli "default_app", "install", id: "install-after-ios--self", before: [%w[build ios --self]]
    cli "default_app", "install", "--device", "00008110-000A1C3A0E38801E", "-v", before: [%w[build ios --self]]
    cli "default_app", "install", "-d", "9FE7A9DF-85B7-4F12-91DB-0868ECEC72B8", before: [%w[build ios --self]]
    cli "default_app", "install", "-d", "9FE7A9DF-85B7-4F12-91DB-0868ECEC72B8", id: "install-simulator-after-ios--self--no-codesign",
                                  before: [%w[build ios --self --no-codesign]]
    cli "default_app", "install", "--device", "emulator-5554", before: [%w[build apk --self]]

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

    # --- Rails project: rake tasks and the plain CLI in Rails.root ------------
    cli "rails_app", "ruflet:build[apk]", rake: true
    cli "rails_app", "ruflet:build[ios]", rake: true
    cli "rails_app", "ruflet:build[desktop]", rake: true
    cli "rails_app", "ruflet:build[web]", rake: true
    cli "rails_app", "ruflet:build[]", id: "rake-ruflet-build-without-platform", rake: true
    cli "rails_app", "build", "apk"
    cli "rails_app", "build", "web"

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

    # --- command words, help, usage and exit codes (R2, CLI-12) ----------------
    # How the first argument picks a command (case-insensitively, aliases
    # included), what help prints, and what every command does with --help and
    # -h today. Mixed-case words get an explicit id: their slug would collide
    # with the lowercase golden on a case-insensitive filesystem.
    cli "empty", "VERSION", id: "version-uppercase"
    cli "empty", "-V", id: "-v-uppercase"
    cli "empty", "--Version", id: "--version-mixed-case"
    cli "empty", "HELP", id: "help-uppercase"
    cli "empty", "-H", id: "-h-uppercase"
    cli "empty", "Bogus-Command", id: "bogus-command-mixed-case"
    cli "empty", "", id: "empty-command"
    cli "empty", "version", "extra"
    cli "empty", "help", "bogus"
    cli "empty", "--help", "build"
    cli "empty", "create"
    cli "empty", "bootstrap"
    cli "empty", "init"
    cli "empty", "CREATE", id: "create-uppercase"
    cli "empty", "New", "my_app", id: "new-my_app-mixed-case"
    %w[--help -h].each do |flag|
      %w[version help new create].each { |command| cli "empty", command, flag }
      %w[run update debug build install devices emulators doctor].each { |command| cli "default_app", command, flag }
    end

    INVOCATIONS.freeze

    # Initial page patch goldens: what a client receives in reply to
    # register_client for each fixture app.
    PAGES = [
      { "fixture" => "default_app", "entrypoint" => "main.rb" },
      { "fixture" => "services_app", "entrypoint" => "main.rb" },
      { "fixture" => "rails_app", "entrypoint" => "app/views/ruflet/main.rb", "rails" => true },
      *DOCS_APPS.map { |id| { "fixture" => "docs_#{id}", "entrypoint" => "main.rb" } },
      *DOCS_RAILS_APPS.map do |id|
        {
          "fixture" => "docs_#{id}",
          "entrypoint" => "main.rb",
          "rails" => true,
          # The Rails host sets this in config/initializers/ruflet.rb.
          "prelude" => 'Ruflet::Rails.config.backend_url = "https://app.test"'
        }
      end
    ].freeze
  end
end
