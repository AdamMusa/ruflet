# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

class RufletCliUpdateCommandTest < Minitest::Test
  class DummyUpdater
    include Ruflet::CLI::UpdateCommand
  end

  class DummyBuilder
    include Ruflet::CLI::BuildCommand
  end

  def services_app_config
    {
      "_app_identity_source" => "services.yaml",
      "app" => {
        "app_name" => "Test App",
        "package_name" => "test_app",
        "organization" => "com.example"
      }
    }
  end

  def test_existing_managed_client_is_replaced_when_template_revision_changes
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      template_dir = File.join(dir, "template")
      FileUtils.mkdir_p(client_dir)
      FileUtils.mkdir_p(template_dir)
      File.write(File.join(client_dir, ".metadata"), "managed\n")
      File.write(File.join(client_dir, "stale.txt"), "old\n")

      copied = []
      previous_dir = Dir.pwd
      Dir.chdir(dir)
      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_dir) do
        Ruflet::CLI.stub(:client_template_current?, false) do
          Ruflet::CLI.stub(:copy_ruflet_client_template, ->(root) { copied << root }) do
            assert_equal File.realpath(client_dir), File.realpath(builder.send(:ensure_flutter_client_dir))
          end
        end
      end

      assert_equal [File.realpath(dir)], copied.map { |path| File.realpath(path) }
    ensure
      Dir.chdir(previous_dir) if previous_dir
    end
  end

  def test_invalid_nested_managed_client_is_repaired_before_build
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      nested = File.join(client_dir, "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(nested, "lib"))
      File.write(File.join(nested, "pubspec.yaml"), "name: nested\n")
      File.write(File.join(nested, "lib", "main.dart"), "void main() {}\n")

      previous_dir = Dir.pwd
      Dir.chdir(dir)
      Ruflet::CLI.stub(:copy_ruflet_client_template, lambda { |root|
        FileUtils.rm_rf(File.join(root, "build", "client"))
        repaired = File.join(root, "build", "client")
        FileUtils.mkdir_p(File.join(repaired, "lib"))
        File.write(File.join(repaired, "pubspec.yaml"), "name: repaired\n")
        File.write(File.join(repaired, "lib", "main.dart"), "void main() {}\n")
      }) do
        assert_equal File.realpath(client_dir), File.realpath(builder.send(:ensure_flutter_client_dir))
      end

      assert File.file?(File.join(client_dir, "pubspec.yaml"))
      refute File.exist?(nested)
    ensure
      Dir.chdir(previous_dir) if previous_dir
    end
  end

  def test_ios_build_refreshes_native_renderer_bootstrap_and_apple_package
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      managed = {
        "lib/main.dart" => "template main\n",
        "lib/native_renderer.dart" => "dart native bridge\n",
        "ios/Runner/Info.plist" => "template plist\n",
        "ios/Runner/AppDelegate.swift" => "native app delegate\n",
        "ios/Runner/RufletEngineChoice.swift" => "native engine choice\n",
        "ios/Runner.xcodeproj/project.pbxproj" => "ruflet apple package link\n",
        "apple_packages/ruflet_apple/Package.swift" => "native package\n",
        "apple_packages/ruflet_apple/Sources/RufletApple/RufletApple.swift" => "native renderer\n",
        "apple_packages/ruflet_apple/.build/stale" => "generated\n",
        "apple_packages/ruflet_apple/.dart_tool/stale" => "generated\n",
        "apple_packages/ruflet_apple/.swiftpm/stale" => "generated\n"
      }
      managed.each do |relative, content|
        path = File.join(template_dir, relative)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
      FileUtils.mkdir_p(File.join(client_dir, "ios", "Runner"))
      File.write(File.join(client_dir, "ios", "Runner", "AppDelegate.swift"), "old flutter host\n")

      Ruflet::CLI.stub(:resolve_ruflet_client_template_root, template_dir) do
        builder.send(
          :refresh_managed_client_template_files,
          client_dir, platform: "ios")
      end

      assert_equal(
        "native app delegate\n",
        File.read(File.join(client_dir, "ios", "Runner", "AppDelegate.swift")))
      assert_equal(
        "dart native bridge\n",
        File.read(File.join(client_dir, "lib", "native_renderer.dart")))
      assert_equal(
        "native engine choice\n",
        File.read(File.join(client_dir, "ios", "Runner", "RufletEngineChoice.swift")))
      assert_equal(
        "ruflet apple package link\n",
        File.read(File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj")))
      assert_equal(
        "native renderer\n",
        File.read(File.join(
          client_dir, "apple_packages", "ruflet_apple", "Sources", "RufletApple",
          "RufletApple.swift")))
      refute_path_exists File.join(client_dir, "apple_packages", "ruflet_apple", ".build")
      refute_path_exists File.join(client_dir, "apple_packages", "ruflet_apple", ".dart_tool")
      refute_path_exists File.join(client_dir, "apple_packages", "ruflet_apple", ".swiftpm")
      refute_path_exists File.join(
        client_dir, "apple_packages", "ruflet_apple", "ruflet_apple")
    end
  end

  def test_native_apple_runtime_configuration_uses_actual_embedded_project_name
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      plist = File.join(dir, "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(plist, "<plist><dict></dict></plist>\n")
      previous = Dir.pwd
      project = File.join(dir, "my_explorer")
      FileUtils.mkdir_p(project)
      Dir.chdir(project) do
        builder.send(
          :configure_native_apple_runtime,
          dir, platform: "ios", self_contained: true)
      end

      content = File.read(plist)
      assert_includes content, "<key>RufletEmbeddedProject</key>"
      assert_includes content, "<string>my_explorer</string>"
    ensure
      Dir.chdir(previous) if previous
    end
  end

  def test_native_apple_runtime_configuration_leaves_server_url_to_dart
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      plist = File.join(dir, "macos", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(plist, <<~PLIST)
        <plist><dict>
        <key>RufletEmbeddedProject</key><string>stale</string>
        <key>RufletBackendURL</key><string>must-not-be-used</string>
        </dict></plist>
      PLIST
      builder.send(
        :configure_native_apple_runtime,
        dir, platform: "macos", self_contained: false)

      content = File.read(plist)
      assert_match(/<key>RufletEmbeddedProject<\/key>\s*<string><\/string>/, content)
      assert_includes content, "<string>must-not-be-used</string>"
    end
  end

  def test_ruflet_yaml_identity_wins_over_services_yaml
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      File.write(
        File.join(dir, "ruflet.yaml"),
        "app:\n  app_name: Legacy Name\n  package_name: legacy_name\n  organization: com.legacy\nextensions:\n  - audio\n"
      )
      File.write(
        File.join(dir, "services.yaml"),
        <<~YAML
          app:
            app_name: Voice Journal
            package_name: voice_journal
            organization: com.acme
          services:
            - microphone:
                description: Record voice notes.
            - location:
                description: Show the current location.
            - motion:
                description: Read device sensors.
        YAML
      )

      manifest = File.join(dir, "client", "android", "app", "src", "main", "AndroidManifest.xml")
      plist = File.join(dir, "client", "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.dirname(manifest))
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(manifest, "<manifest><application/></manifest>\n")
      File.write(plist, "<plist><dict></dict></plist>\n")

      Dir.chdir(dir) do
        config = builder.send(:load_ruflet_config)
        builder.send(:apply_native_service_permissions, File.join(dir, "client"), config)
        metadata = builder.send(:build_client_metadata, config, File.join(dir, "client"))

        # Services still come from services.yaml, but the app is declared by
        # ruflet.yaml, so its identity is the one that ships.
        assert_equal 3, config["services"].length
        assert_equal "Legacy Name", config.dig("app", "app_name")
        assert_equal "legacy_name", config.dig("app", "package_name")
        assert_equal "com.legacy", config.dig("app", "organization")
        assert_equal "Legacy Name", metadata[:display_name]
        assert_equal "com.legacy.legacy_name", metadata[:android_application_id]
        assert_equal "com.legacy.legacy-name", metadata[:ios_bundle_identifier]
        assert_empty metadata[:mobile_identity_errors]
      end

      android = File.read(manifest)
      assert_includes android, "android.permission.RECORD_AUDIO"
      assert_includes android, "android.permission.ACCESS_FINE_LOCATION"
      assert_includes android, "android.permission.HIGH_SAMPLING_RATE_SENSORS"

      ios = File.read(plist)
      assert_includes ios, "NSMicrophoneUsageDescription"
      assert_includes ios, "Record voice notes."
      assert_includes ios, "NSLocationWhenInUseUsageDescription"
      assert_includes ios, "NSMotionUsageDescription"
    end
  end

  def test_services_activate_only_their_required_client_extensions
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        "dependencies:\n  flutter:\n    sdk: flutter\n  flet: any\n"
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        <<~DART
          import 'package:flet/flet.dart';
          void main() {
            final extensions = <FletExtension>[
            ];
          }
        DART
      )

      config = { "services" => ["microphone", "location"] }
      builder.send(:apply_service_extension_config, client_dir, config, self_contained: true)

      pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
      dependencies = pubspec.fetch("dependencies")
      assert dependencies.key?("flet_audio_recorder")
      assert dependencies.key?("flet_geolocator")
      assert dependencies.key?("flet_permission_handler")
      refute dependencies.key?("flet_camera")
      refute dependencies.key?("flet_video")

      main = File.read(File.join(client_dir, "lib", "main.self.dart"))
      assert_includes main, "ruflet_audio_recorder.Extension(),"
      assert_includes main, "ruflet_geolocator.Extension(),"
      assert_includes main, "ruflet_permission_handler.Extension(),"
      refute_includes main, "ruflet_camera.Extension(),"
    end
  end

  def test_qrcode_scanner_adds_extension_and_camera_permissions
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      manifest = File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")
      plist = File.join(client_dir, "ios", "Runner", "Info.plist")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      FileUtils.mkdir_p(File.dirname(manifest))
      FileUtils.mkdir_p(File.dirname(plist))
      File.write(File.join(client_dir, "pubspec.yaml"), "dependencies:\n  flet: any\n")
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        "import 'package:flet/flet.dart';\nfinal extensions = <FletExtension>[\n];\n"
      )
      File.write(manifest, "<manifest><application/></manifest>\n")
      File.write(plist, "<plist><dict></dict></plist>\n")

      config = { "extensions" => ["qrcode_scanner"] }
      builder.send(:apply_service_extension_config, client_dir, config, self_contained: true)
      builder.send(:apply_native_service_permissions, client_dir, config)

      dependencies = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true).fetch("dependencies")
      assert dependencies.key?("ruflet_qrcode_scanner")
      assert_includes File.read(File.join(client_dir, "lib", "main.self.dart")), "ruflet_qrcode_scanner.Extension(),"
      assert_includes File.read(manifest), "android.permission.CAMERA"
      assert_includes File.read(plist), "NSCameraUsageDescription"
    end
  end

  def test_command_update_check_reports_manifest_status
    updater = DummyUpdater.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")
      File.write(File.join(dir, "web", "flutter_bootstrap.js"), "// built")

      updater.define_singleton_method(:host_platform_name) { "macos" }
      updater.define_singleton_method(:ruflet_version) { "0.0.8" }
      updater.define_singleton_method(:client_cache_root_for) { |_platform| dir }
      updater.define_singleton_method(:read_client_manifest) do |_root|
        { "release_tag" => "v0.0.8" }
      end
      updater.define_singleton_method(:prebuilt_desktop_present?) { |_root, platform: nil| platform == "macos" }

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      code = updater.command_update(["--check", "--web", "--desktop"])

      assert_equal 0, code
      assert_includes out.string, "Release tag: v0.0.8"
      assert_includes out.string, "web: installed"
      assert_includes out.string, "desktop: installed"
    ensure
      $stdout = original_stdout
    end
  end

  def test_command_update_downloads_requested_target_for_platform
    updater = DummyUpdater.new
    calls = []
    updater.define_singleton_method(:ensure_prebuilt_client) do |**kwargs|
      calls << kwargs
      "/tmp/ruflet-cache"
    end
    updater.define_singleton_method(:read_client_manifest) do |_root|
      { "release_tag" => "v0.0.8" }
    end

    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = updater.command_update(["desktop", "--platform", "linux"])

    assert_equal 0, code
    assert_equal [{ desktop: true, platform: "linux", force: false }], calls
    assert_includes out.string, "Updated desktop client for linux"
  ensure
    $stdout = original_stdout
  end

  def test_new_app_gemfile_uses_current_runtime_package_versions
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_core", ">= #{Ruflet::VERSION}")
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_server", ">= #{Ruflet::VERSION}")
    refute_includes Ruflet::CLI::GEMFILE_TEMPLATE, "0.0.10"
  end

  def test_prepare_flutter_client_uses_source_ruby_runtime_dependency
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            ruby_runtime: ^0.0.3
        YAML
      )

      calls = []
      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << chdir
        true
      end

      builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "apk",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: services_app_config,
        self_contained: true,
        verbose: false
      )

      refute_path_exists File.join(client_dir, "pubspec_overrides.yaml")
      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      ruby_runtime = YAML.safe_load(pubspec, aliases: true).dig("dependencies", "ruby_runtime")
      assert_equal File.expand_path("../../../ruby_runtime", __dir__), ruby_runtime["path"]
      refute YAML.safe_load(pubspec, aliases: true).dig("dependencies", "flet_spinkit")
      refute_path_exists File.join(client_dir, "lib", "ruflet_spinkit.dart")
      assert_includes calls, client_dir
    end
  end

  def test_prepare_flutter_client_uses_explicit_local_ruby_runtime_override
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      runtime_dir = File.join(dir, "ruby_runtime")
      FileUtils.mkdir_p(client_dir)
      FileUtils.mkdir_p(runtime_dir)
      File.write(File.join(runtime_dir, "pubspec.yaml"), "name: ruby_runtime\n")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            ruby_runtime: ^0.0.3
        YAML
      )

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }
      builder.define_singleton_method(:system) { |_env, *_args, chdir: nil| true }

      original_env = ENV["RUFLET_RUBY_RUNTIME_PATH"]
      ENV["RUFLET_RUBY_RUNTIME_PATH"] = runtime_dir

      builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "apk",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: services_app_config,
        self_contained: true,
        verbose: false
      )

      pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
      ruby_runtime = pubspec.dig("dependencies", "ruby_runtime")
      assert_equal({ "path" => runtime_dir }, ruby_runtime)
    ensure
      ENV["RUFLET_RUBY_RUNTIME_PATH"] = original_env
    end
  end

  def test_stages_static_ruby_runtime_slice_for_ios_simulator_build
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      runtime_dir = File.join(dir, "ruby_runtime")
      slice_dir = File.join(
        runtime_dir,
        "ios",
        "Frameworks",
        "RufletVM.xcframework",
        "ios-arm64_x86_64-simulator"
      )
      FileUtils.mkdir_p(File.join(slice_dir, "Headers"))
      File.write(File.join(runtime_dir, "pubspec.yaml"), "name: ruby_runtime\n")
      File.write(File.join(slice_dir, "libruflet_vm.a"), "simulator-library")
      File.write(File.join(slice_dir, "Headers", "mruby.h"), "header")

      previous_runtime = ENV["RUFLET_RUBY_RUNTIME_PATH"]
      ENV["RUFLET_RUBY_RUNTIME_PATH"] = runtime_dir

      builder.send(
        :stage_ios_simulator_ruby_runtime,
        client_dir,
        ["build", "ios", "--simulator"],
        verbose: false
      )

      destination = File.join(
        client_dir,
        "build",
        "ios",
        "Debug-iphonesimulator",
        "XCFrameworkIntermediates",
        "ruby_runtime"
      )
      assert_equal "simulator-library", File.read(File.join(destination, "libruflet_vm.a"))
      assert_equal "header", File.read(File.join(destination, "Headers", "mruby.h"))
    ensure
      ENV["RUFLET_RUBY_RUNTIME_PATH"] = previous_runtime
    end
  end

  def test_write_pubspec_yaml_indents_flutter_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      path = File.join(dir, "pubspec.yaml")

      builder.send(
        :write_pubspec_yaml,
        path,
        {
          "flutter" => {
            "uses-material-design" => true,
            "assets" => ["assets/ruflet_studio/"]
          }
        }
      )

      pubspec = File.read(path)
      assert_includes pubspec, "  assets:\n    - assets/ruflet_studio/"
      refute_includes pubspec, "  assets:\n- assets/ruflet_studio/"
    end
  end

  # A self-contained build embeds only what the app needs at runtime: the
  # entrypoint, lib/, and assets/ that code loads by path. The gems live in the
  # VM and the yaml config has already been applied to the native project.
  def test_project_asset_filter_packages_only_the_runtime_project
    builder = DummyBuilder.new

    assert builder.send(:include_project_asset_file?, "main.rb")
    assert builder.send(:include_project_asset_file?, "lib/widgets.rb")
    assert builder.send(:include_project_asset_file?, "lib/studio/lib/gallery.rb")
    assert builder.send(:include_project_asset_file?, "assets/icon.png")
    assert builder.send(:include_project_asset_file?, "assets/animations/success.json")
  end

  def test_project_asset_filter_leaves_out_everything_that_is_not_runtime
    builder = DummyBuilder.new

    # Consumed by the build, or already compiled into the VM.
    refute builder.send(:include_project_asset_file?, "Gemfile")
    refute builder.send(:include_project_asset_file?, "Gemfile.lock")
    refute builder.send(:include_project_asset_file?, "ruflet.yaml")
    refute builder.send(:include_project_asset_file?, "services.yaml")
    # Never runtime inputs. release_assets carried a lockfile that Apple read as
    # an unsigned code object and rejected the upload over.
    refute builder.send(:include_project_asset_file?, "release_assets/generator/bun.lockb")
    refute builder.send(:include_project_asset_file?, "test/app_test.rb")
    refute builder.send(:include_project_asset_file?, "README.md")
    refute builder.send(:include_project_asset_file?, "android/key.properties")
    refute builder.send(:include_project_asset_file?, "fastlane/Fastfile")
  end

  def test_project_asset_filter_prunes_hidden_workspace_directories
    builder = DummyBuilder.new

    assert builder.send(:skip_project_asset_directory?, ".claude/worktrees/example")
    assert builder.send(:skip_project_asset_directory?, "nested/.git")
    refute builder.send(:skip_project_asset_directory?, "standalone_apps/example")
  end

  def test_prune_client_pubspec_preserves_formatted_flutter_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      path = File.join(dir, "pubspec.yaml")
      File.write(
        path,
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            flet: any
            flet_audio: any
            flet_webview: any
          flutter:
            assets:
              - assets/demo/
        YAML
      )

      builder.send(:prune_client_pubspec, path, [])

      pubspec = File.read(path)
      assert_includes pubspec, "  assets:\n    - assets/demo/"
      refute_includes pubspec, "  assets:\n- assets/demo/"
      refute_includes pubspec, "flet_audio:"
      refute_includes pubspec, "flet_webview:"
    end
  end

  def test_self_contained_service_extension_config_only_restores_configured_extensions
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(template_dir, "lib"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))

      File.write(
        File.join(template_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            flet: any
            flet_webview: any
        YAML
      )
      File.write(
        File.join(template_dir, "lib", "main.self.dart"),
        <<~DART
          import 'package:flet/flet.dart';
          import 'package:flet_webview/flet_webview.dart' as ruflet_webview;

          void main() {
            final extensions = <FletExtension>[
              ruflet_webview.Extension(),
            ];
          }
        DART
      )
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            flet: any
        YAML
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        <<~DART
          import 'package:flet/flet.dart';

          void main() {
            final extensions = <FletExtension>[
            ];
          }
        DART
      )

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        config = { "extensions" => ["webview"] }
        builder.send(:apply_service_extension_config, client_dir, config, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        assert_equal "any", pubspec.dig("dependencies", "flet_webview")

        main = File.read(File.join(client_dir, "lib", "main.self.dart"))
        assert_includes main, "import 'package:flet_webview/flet_webview.dart' as ruflet_webview;"
        assert_includes main, "ruflet_webview.Extension(),"
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_update_pubspec_value_preserves_formatted_flutter_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      path = File.join(dir, "pubspec.yaml")
      File.write(
        path,
        <<~YAML
          flutter_launcher_icons:
            image_path: "assets/icon.png"
          flutter:
            uses-material-design: true
            assets:
            - assets/demo/
        YAML
      )

      builder.send(:update_pubspec_value, path, "flutter_launcher_icons", "theme_color", "\"#FFFFFF\"")

      pubspec = File.read(path)
      assert_includes pubspec, "  assets:\n    - assets/demo/"
      refute_includes pubspec, "  assets:\n  - assets/demo/"
      refute_includes pubspec, "  assets:\n- assets/demo/"
    end
  end

  def test_prepare_flutter_client_server_mode_removes_ruby_runtime_dependency_and_override
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            ruby_runtime: ^0.0.3
          flutter:
            assets:
              - assets/ruflet/
        YAML
      )
      File.write(
        File.join(client_dir, "pubspec_overrides.yaml"),
        <<~YAML
          dependency_overrides:
            ruby_runtime:
              path: ../ruby_runtime
        YAML
      )

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }
      builder.define_singleton_method(:system) { |_env, *_args, chdir: nil| true }

      builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "ios",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: services_app_config,
        self_contained: false,
        verbose: false
      )

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      refute_includes pubspec, "ruby_runtime"
      refute_includes pubspec, "assets/ruflet/"
      refute File.exist?(File.join(client_dir, "pubspec_overrides.yaml"))
    end
  end

  def test_command_build_verbose_logs_bootstrap_and_passes_v_to_flutter
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
      File.write(File.join(client_dir, "lib", "main.server.dart"), "void main() {}\n")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { { "app" => { "backend_url" => "https://api.example.com" } } }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: { "PATH" => "/tmp/bin" } }
      end
      builder.define_singleton_method(:prepare_flutter_client) do |_client_dir, platform: nil, tools:, config:, self_contained: false, verbose: false|
        puts "[ruflet build] running flutter pub get" if verbose
        true
      end

      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { args: _args, chdir: chdir }
        true
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      code = builder.command_build(["apk", "--self", "--verbose"])

      assert_equal 0, code
      assert_includes out.string, "[ruflet build] running flutter pub get"
      assert_includes out.string, "[ruflet build] mode=self"
      assert_includes out.string, "[ruflet build] target=lib/main.self.dart"
      assert_includes out.string, "[ruflet build] command=flutter build apk --target lib/main.self.dart --dart-define RUFLET_EMBEDDED_PROJECT=ruflet -v"
      assert_equal ["flutter", "build", "apk", "--target", "lib/main.self.dart", "--dart-define", "RUFLET_EMBEDDED_PROJECT=ruflet", "-v"], calls.first[:args]
      assert_equal client_dir, calls.first[:chdir]
    ensure
      $stdout = original_stdout
    end
  end

  def test_command_build_bootstraps_missing_flutter_client_from_template
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)

      copied = []
      original_copy_method = Ruflet::CLI.method(:copy_ruflet_client_template)
      Ruflet::CLI.define_singleton_method(:copy_ruflet_client_template) do |root|
        copied << root
        client_dir = File.join(root, "build", "client")
        FileUtils.mkdir_p(File.join(client_dir, "lib"))
        File.write(File.join(client_dir, "pubspec.yaml"), "name: ruflet_client\n")
        File.write(File.join(client_dir, "lib", "main.server.dart"), "void main() {}\n")
      end
      Ruflet::CLI.singleton_class.send(:private, :copy_ruflet_client_template)

      builder.define_singleton_method(:load_ruflet_config) { { "app" => { "backend_url" => "https://api.example.com" } } }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) do |_client_dir, platform: nil, tools:, config:, self_contained: false, verbose: false|
        true
      end

      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { args: _args, chdir: chdir }
        true
      end

      code = builder.command_build(["ios"])

      assert_equal 0, code
      assert_equal [File.realpath(dir)], copied.map { |path| File.realpath(path) }
      assert_equal File.realpath(File.join(dir, "build", "client")), File.realpath(calls.first[:chdir])
      assert_equal ["flutter", "build", "ios", "--codesign", "--target", "lib/main.server.dart", "--dart-define", "RUFLET_BACKEND_URL=https://api.example.com"], calls.first[:args]
    ensure
      Ruflet::CLI.define_singleton_method(:copy_ruflet_client_template, original_copy_method) if original_copy_method
      Ruflet::CLI.singleton_class.send(:private, :copy_ruflet_client_template) if original_copy_method
      Dir.chdir(previous_dir)
    end
  end

  def test_command_build_runs_full_first_time_setup_before_prepare
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)

      events = []
      client_dir = File.join(dir, "build", "client")

      builder.define_singleton_method(:download_ruflet_assets) do |force: false, verbose: false|
        events << [:assets, force, verbose]
        true
      end
      builder.define_singleton_method(:detect_flutter_client_dir) do
        Dir.exist?(client_dir) ? client_dir : nil
      end
      builder.define_singleton_method(:bootstrap_flutter_client_template) do
        events << [:template]
        FileUtils.mkdir_p(File.join(client_dir, "lib"))
        File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
        File.write(File.join(client_dir, "lib", "main.server.dart"), "void main() {}\n")
        client_dir
      end
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        events << [:flutter, File.realpath(client_dir), auto_install]
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) do |_client_dir, platform:, tools:, config:, self_contained: false, verbose: false|
        events << [:prepare, File.realpath(_client_dir), self_contained]
        true
      end
      builder.define_singleton_method(:system) { |_env, *_args, chdir: nil| true }

      code = builder.command_build(["apk", "--self"])

      assert_equal 0, code
      assert_equal [
        [:assets, false, false],
        [:template],
        [:flutter, File.realpath(client_dir), true],
        [:prepare, File.realpath(client_dir), true]
      ], events
    ensure
      Dir.chdir(previous_dir)
    end
  end

  def test_command_update_bootstraps_flutter_environment
    updater = DummyUpdater.new
    events = []

    updater.define_singleton_method(:host_platform_name) { "linux" }
    updater.define_singleton_method(:ensure_cached_ruflet_assets_for_update) do |force: false, verbose: false|
      events << [:assets, force, verbose]
      true
    end
    updater.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
      events << [:flutter, client_dir, auto_install]
      { flutter: "flutter", dart: "dart", env: {} }
    end
    updater.define_singleton_method(:ensure_prebuilt_client) do |**kwargs|
      events << [:prebuilt, kwargs]
      "/tmp/ruflet-cache"
    end
    updater.define_singleton_method(:read_client_manifest) { |_root| { "release_tag" => "v0.0.8" } }

    out = StringIO.new
    original_stdout = $stdout
    $stdout = out

    code = updater.command_update(["web"])

    assert_equal 0, code
    assert_equal [
      [:assets, false, false],
      [:flutter, nil, true],
      [:prebuilt, { web: true, platform: "linux", force: false }]
    ], events
  ensure
    $stdout = original_stdout
  end

  def test_export_platform_build_outputs_copies_hidden_android_outputs_to_user_build_dir
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)

      client_dir = File.join(dir, "build", "client")
      source_dir = File.join(client_dir, "build", "app", "outputs", "flutter-apk")
      FileUtils.mkdir_p(source_dir)
      File.write(File.join(source_dir, "app-release.apk"), "apk")

      builder.send(:export_platform_build_outputs, client_dir, "android", verbose: false)

      assert File.exist?(File.join(dir, "build", "android", "flutter-apk", "app-release.apk"))
    ensure
      Dir.chdir(previous_dir)
    end
  end

  def test_command_build_requires_backend_url_for_server_driven_mode
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.server.dart"), "void main() {}\n")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) { |_client_dir, platform: nil, tools:, config:, self_contained: false, verbose: false| true }
      builder.define_singleton_method(:system) { |_env, *_args, chdir: nil| flunk("system should not be called without backend_url") }

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      code = builder.command_build(["ios"])

      assert_equal 1, code
      assert_includes err.string, "build config error: backend_url is required for server-driven builds"
    ensure
      $stderr = original_stderr
    end
  end

  def test_command_build_ios_uses_unbundled_env_for_flutter
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        {
          flutter: "flutter",
          dart: "dart",
          env: {
            "BUNDLE_GEMFILE" => "/tmp/example/Gemfile",
            "PATH" => "/Users/macbookpro/.gem/ruby/3.4.0/bin:/tmp/bin",
            "GEM_HOME" => "/Users/macbookpro/.gem/ruby/3.4.0",
            "GEM_PATH" => "/Users/macbookpro/.gem/ruby/3.4.0:/opt/homebrew/lib/ruby/gems/3.4.0"
          }
        }
      end
      test = self
      builder.define_singleton_method(:prepare_flutter_client) do |_client_dir, platform:, tools:, config:, self_contained: false, verbose: false|
        test.refute tools[:env].key?("BUNDLE_GEMFILE")
        test.refute_includes tools[:env]["PATH"], "/Users/macbookpro/.gem/ruby/3.4.0/bin"
        test.assert_includes tools[:env]["PATH"], File.join(client_dir, ".ruflet", "bin")
        test.assert_nil tools[:env]["GEM_HOME"]
        test.assert_nil tools[:env]["GEM_PATH"]
        true
      end

      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { env: _env, args: _args, chdir: chdir }
        true
      end

      code = builder.command_build(["ios", "--self"])

      assert_equal 0, code
      refute calls.first[:env].key?("BUNDLE_GEMFILE")
      assert_equal ["flutter", "build", "ios", "--codesign", "--target", "lib/main.self.dart", "--dart-define", "RUFLET_EMBEDDED_PROJECT=ruflet"], calls.first[:args]
      assert_equal ["flutter", "build", "ios", "--simulator", "--target", "lib/main.self.dart", "--dart-define", "RUFLET_EMBEDDED_PROJECT=ruflet"], calls.last[:args]
      refute_includes calls.first[:env]["PATH"], "/Users/macbookpro/.gem/ruby/3.4.0/bin"
      assert_includes calls.first[:env]["PATH"], File.join(client_dir, ".ruflet", "bin")
      assert File.executable?(File.join(client_dir, ".ruflet", "bin", "pod"))
      assert_nil calls.first[:env]["GEM_HOME"]
      assert_nil calls.first[:env]["GEM_PATH"]
    end
  end

  def test_command_install_syncs_android_build_outputs_and_runs_flutter_install
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
      apk_dir = File.join(dir, "build", "android", "flutter-apk")
      FileUtils.mkdir_p(apk_dir)
      File.write(File.join(apk_dir, "app-release.apk"), "apk")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) { |_client_dir, **_kwargs| flunk("install should not run build preparation") }

      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { env: _env, args: _args, chdir: chdir }
        true
      end

      code = builder.command_install(["--device", "emulator-5554"])

      assert_equal 0, code
      assert_equal ["flutter", "install", "-d", "emulator-5554"], calls.first[:args]
      assert_equal client_dir, calls.first[:chdir]
      assert File.exist?(File.join(client_dir, "build", "app", "outputs", "flutter-apk", "app-release.apk"))
    ensure
      Dir.chdir(previous_dir)
    end
  end

  def test_command_install_syncs_ios_build_outputs_and_runs_flutter_install
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
      ios_app_dir = File.join(dir, "build", "ios", "iphonesimulator", "Runner.app")
      FileUtils.mkdir_p(ios_app_dir)
      File.write(File.join(ios_app_dir, "Info.plist"), "plist")
      File.write(File.join(ios_app_dir, "Runner"), "simulator executable")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) { |_client_dir, **_kwargs| flunk("install should not run build preparation") }
      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { env: _env, args: _args, chdir: chdir }
        true
      end

      code = builder.command_install([])

      assert_equal 0, code
      assert_equal ["flutter", "install"], calls.first[:args]
      assert_equal client_dir, calls.first[:chdir]
      assert File.exist?(File.join(client_dir, "build", "ios", "iphonesimulator", "Runner.app", "Info.plist"))
    ensure
      Dir.chdir(previous_dir)
    end
  end

  def test_command_install_refuses_unsigned_ios_device_app
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.self.dart"), "void main() {}\n")
      ios_app_dir = File.join(dir, "build", "ios", "iphoneos", "Runner.app")
      FileUtils.mkdir_p(ios_app_dir)
      File.write(File.join(ios_app_dir, "Info.plist"), "plist")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) { |_client_dir, **_kwargs| flunk("install should not run build preparation") }

      calls = []
      builder.define_singleton_method(:system) do |_env_or_command, *args, chdir: nil, **_kwargs|
        calls << { command: _env_or_command, args: args, chdir: chdir }
        false
      end

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      code = builder.command_install(["--device", "00008140-0019590E3C87001C"])

      assert_equal 1, code
      assert_equal "/usr/bin/codesign", calls.first[:command]
      assert_includes err.string, "iOS device app bundle is not code signed"
      refute calls.any? { |call| call[:args].include?("install") }
    ensure
      $stderr = original_stderr
      Dir.chdir(previous_dir)
    end
  end

  def test_command_install_fails_when_no_built_outputs_exist
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      previous_dir = Dir.pwd
      Dir.chdir(dir)
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(client_dir, "lib", "main.server.dart"), "void main() {}\n")

      builder.define_singleton_method(:detect_flutter_client_dir) { client_dir }
      builder.define_singleton_method(:load_ruflet_config) { {} }
      builder.define_singleton_method(:ensure_flutter!) do |_command_name, client_dir: nil, auto_install: true|
        { flutter: "flutter", dart: "dart", env: {} }
      end
      builder.define_singleton_method(:prepare_flutter_client) { |_client_dir, **_kwargs| flunk("install should not run build preparation") }
      builder.define_singleton_method(:system) { |_env, *_args, chdir: nil| flunk("install should not run without built outputs") }

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      code = builder.command_install([])

      assert_equal 1, code
      assert_includes err.string, "Could not find built app outputs under ./build"
    ensure
      $stderr = original_stderr
      Dir.chdir(previous_dir) if previous_dir
    end
  end

  def test_build_refuses_a_self_contained_web_target
    builder = DummyBuilder.new
    builder.define_singleton_method(:prepare_flutter_client) { |*, **| flunk("must not prepare a client") }

    err = StringIO.new
    original_stderr = $stderr
    $stderr = err

    code = builder.command_build(["web", "--self"])

    assert_equal 1, code
    assert_includes err.string, "--self is not supported for web"
  ensure
    $stderr = original_stderr
  end

  def test_apply_build_config_falls_back_to_template_assets_when_custom_files_are_missing
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          flutter_native_splash:
            image: assets/splash.png
          flutter_launcher_icons:
            image_path: "assets/icon.png"
        YAML
      )

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      result = builder.send(
        :apply_build_config,
        client_dir,
        {
          "assets" => {
            "splash_screen" => "missing/splash.png",
            "icon_launcher" => "missing/icon.png"
          }
        }
      )

      assert_nil result[:error]
      assert_equal true, result[:has_splash]
      assert_equal true, result[:has_icon]
      assert_equal true, result[:using_default_splash]
      assert_equal true, result[:using_default_icon]
      assert_includes out.string, "Configured splash_screen was not found; using default template asset"
      assert_includes out.string, "Configured icon_launcher was not found; using default template asset"
    ensure
      $stdout = original_stdout
    end
  end

  def test_apply_build_config_writes_android_splash_and_adaptive_icon_settings
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          flutter_native_splash:
            image: assets/splash.png
          flutter_launcher_icons:
            image_path: "assets/icon.png"
        YAML
      )

      project_assets = File.join(dir, "assets")
      FileUtils.mkdir_p(project_assets)
      %w[splash.png icon.png icon_foreground.png].each do |name|
        File.write(File.join(project_assets, name), "png")
      end

      result = nil
      Dir.chdir(dir) do
        result = builder.send(
          :apply_build_config,
          client_dir,
          {
            "assets" => { "dir" => "assets", "splash_screen" => "assets/splash.png", "icon_launcher" => "assets/icon.png" },
            "build" => { "splash_color" => "#FFFFFF", "splash_dark_color" => "#0B0B0B", "icon_background" => "#FFFFFF" },
            "android" => {
              "adaptive_icon_foreground" => "assets/icon_foreground.png",
              "adaptive_icon_background" => "#101010",
              "min_sdk" => 23
            }
          }
        )
      end

      assert_nil result[:error]
      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))

      assert_match(/^\s{2}android: true$/, pubspec)
      assert_match(/^\s{2}android_12:$/, pubspec)
      assert_match(%r{^\s{4}image: "assets/splash\.png"$}, pubspec)
      assert_match(/^\s{4}icon_background_color: "#FFFFFF"$/, pubspec)
      assert_match(/^\s{4}icon_background_color_dark: "#0B0B0B"$/, pubspec)

      assert_match(/^\s{2}android: launcher_icon$/, pubspec)
      assert_match(%r{^\s{2}adaptive_icon_foreground: "assets/icon_foreground\.png"$}, pubspec)
      assert_match(/^\s{2}adaptive_icon_background: "#101010"$/, pubspec)
      assert_match(/^\s{2}min_sdk_android: 23$/, pubspec)

      assert File.file?(File.join(client_dir, "assets", "icon_foreground.png"))
      assert_equal true, result[:android_adaptive_icon]
      assert_equal true, result[:android_12_splash]
    end
  end

  def test_apply_build_config_defaults_adaptive_foreground_to_the_launcher_icon
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(File.join(client_dir, "pubspec.yaml"), "flutter_launcher_icons:\n  image_path: \"assets/icon.png\"\n")

      builder.send(:apply_build_config, client_dir, {})

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      assert_match(%r{^\s{2}adaptive_icon_foreground: "assets/icon\.png"$}, pubspec)
    end
  end

  def test_apply_build_config_writes_every_platform_section
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          flutter_native_splash:
            image: assets/splash.png
          flutter_launcher_icons:
            image_path: "assets/icon.png"
        YAML
      )

      project_assets = File.join(dir, "assets")
      FileUtils.mkdir_p(project_assets)
      %w[splash.png icon.png splash_ios.png icon_ios.png icon_macos.png icon_win.ico].each do |name|
        File.write(File.join(project_assets, name), "png")
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      Dir.chdir(dir) do
        builder.send(
          :apply_build_config,
          client_dir,
          {
            "assets" => { "dir" => "assets", "splash_screen" => "assets/splash.png", "icon_launcher" => "assets/icon.png" },
            "build" => { "splash_color" => "#FFFFFF", "icon_background" => "#FFFFFF", "theme_color" => "#6750A4" },
            "ios" => {
              "splash_screen" => "assets/splash_ios.png",
              "splash_color" => "#101010",
              "icon_launcher" => "assets/icon_ios.png",
              "remove_alpha" => true,
              "content_mode" => "scaleAspectFit"
            },
            "macos" => { "icon_launcher" => "assets/icon_macos.png" },
            "windows" => { "icon_launcher" => "assets/icon_win.ico", "icon_size" => 64 },
            "linux" => { "icon_launcher" => "assets/icon.png" }
          }
        )
      end

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))

      # iOS takes flat, platform-suffixed keys.
      assert_match(/^\s{2}ios: true$/, pubspec)
      assert_match(%r{^\s{2}image_ios: "assets/splash_ios\.png"$}, pubspec)
      assert_match(/^\s{2}color_ios: "#101010"$/, pubspec)
      assert_match(/^\s{2}ios_content_mode: scaleAspectFit$/, pubspec)
      assert_match(%r{^\s{2}image_path_ios: "assets/icon_ios\.png"$}, pubspec)
      assert_match(/^\s{2}remove_alpha_ios: true$/, pubspec)

      # macOS and Windows take nested blocks.
      assert_match(/^\s{2}macos:$/, pubspec)
      assert_match(%r{^\s{4}image_path: "assets/icon_macos\.png"$}, pubspec)
      assert_match(/^\s{2}windows:$/, pubspec)
      assert_match(%r{^\s{4}image_path: "assets/icon_windows\.ico"$}, pubspec)
      assert_match(/^\s{4}icon_size: 64$/, pubspec)

      assert File.file?(File.join(client_dir, "assets", "icon_macos.png"))
      assert File.file?(File.join(client_dir, "assets", "icon_windows.ico"))
      assert File.file?(File.join(client_dir, "assets", "splash_ios.png"))

      # Linux has no generator in either tool.
      assert_includes out.string, "linux has no launcher icon generator"
      refute File.file?(File.join(client_dir, "assets", "icon_linux.png"))
    ensure
      $stdout = original_stdout
    end
  end

  def test_apply_build_config_leaves_platform_keys_alone_when_no_section_is_given
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          flutter_native_splash:
            image: assets/splash.png
          flutter_launcher_icons:
            image_path: "assets/icon.png"
        YAML
      )

      builder.send(:apply_build_config, client_dir, {})
      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))

      refute_match(/image_ios:/, pubspec)
      refute_match(/image_path_ios:/, pubspec)
      refute_match(/^\s{2}macos:$/, pubspec)
      refute_match(/^\s{2}windows:$/, pubspec)
    end
  end

  def test_apply_build_config_writes_splash_background_and_branding_keys
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(client_dir, "assets", "splash.png"), "png")
      File.write(File.join(client_dir, "assets", "icon.png"), "png")
      File.write(File.join(client_dir, "pubspec.yaml"), "flutter_native_splash:\n  image: assets/splash.png\n")

      project_assets = File.join(dir, "assets")
      FileUtils.mkdir_p(project_assets)
      %w[splash.png bg.png brand.png a12brand.png].each do |name|
        File.write(File.join(project_assets, name), "png")
      end

      Dir.chdir(dir) do
        builder.send(
          :apply_build_config,
          client_dir,
          {
            "assets" => { "dir" => "assets", "splash_screen" => "assets/splash.png" },
            "build" => {
              "splash_background_image" => "assets/bg.png",
              "splash_branding" => "assets/brand.png",
              "splash_branding_mode" => "bottom",
              "splash_branding_bottom_padding" => 24
            },
            "android" => {
              "splash_background_image" => "assets/bg.png",
              "splash_branding" => "assets/brand.png",
              "splash_android_12_color" => "#101010",
              "splash_android_12_color_dark" => "#000000",
              "splash_android_12_branding" => "assets/a12brand.png"
            }
          }
        )
      end

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))

      assert_match(%r{^\s{2}background_image: "assets/splash_background\.png"$}, pubspec)
      assert_match(%r{^\s{2}branding: "assets/splash_branding\.png"$}, pubspec)
      assert_match(/^\s{2}branding_mode: bottom$/, pubspec)
      assert_match(/^\s{2}branding_bottom_padding: 24$/, pubspec)
      assert_match(%r{^\s{2}background_image_android: "assets/splash_background_android\.png"$}, pubspec)
      assert_match(%r{^\s{2}branding_android: "assets/splash_branding_android\.png"$}, pubspec)
      assert_match(/^\s{4}color: "#101010"$/, pubspec)
      assert_match(/^\s{4}color_dark: "#000000"$/, pubspec)
      assert_match(%r{^\s{4}branding: "assets/splash_android_12_branding\.png"$}, pubspec)

      assert File.file?(File.join(client_dir, "assets", "splash_background.png"))
      assert File.file?(File.join(client_dir, "assets", "splash_branding_android.png"))
    end
  end

  def test_project_assets_never_embed_credentials
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "credentials"))
      FileUtils.mkdir_p(File.join(dir, "fastlane"))
      FileUtils.mkdir_p(File.join(dir, "lib"))
      File.write(File.join(dir, "credentials", "AuthKey_ABC123.p8"), "secret")
      File.write(File.join(dir, "fastlane", "Fastfile"), "lane :beta do; end")
      File.write(File.join(dir, "google-play-service-account.json"), "{}")
      File.write(File.join(dir, "signing.keystore"), "secret")
      File.write(File.join(dir, ".env.production"), "TOKEN=abc")
      File.write(File.join(dir, ".env.example"), "TOKEN=")
      File.write(File.join(dir, "main.rb"), "puts 1")
      File.write(File.join(dir, "lib", "app.rb"), "puts 2")

      included = Dir.chdir(dir) { builder.send(:project_asset_relative_paths) }

      assert_includes included, "main.rb"
      assert_includes included, File.join("lib", "app.rb")

      refute_includes included, File.join("credentials", "AuthKey_ABC123.p8")
      refute_includes included, File.join("fastlane", "Fastfile")
      refute_includes included, "google-play-service-account.json"
      refute_includes included, "signing.keystore"
      refute_includes included, ".env.production"
      assert(included.none? { |path| path.end_with?(".p8") }, "no signing key may be embedded")
    end
  end

  def test_android_signing_is_taken_from_the_project_not_the_client
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "android"))
      FileUtils.mkdir_p(File.join(dir, "android"))
      File.write(File.join(dir, "upload.jks"), "keystore")
      File.write(
        File.join(dir, "android", "key.properties"),
        "storePassword=s3cret\nkeyPassword=k3y\nkeyAlias=upload\nstoreFile=../upload.jks\n"
      )

      Dir.chdir(dir) { builder.send(:apply_android_signing_config, client_dir, "aab") }

      written = File.read(File.join(client_dir, "android", "key.properties"))
      assert_includes written, "keyAlias=upload"
      assert_includes written, "storePassword=s3cret"
      # Relative to the project, but the client sits deeper, so it must resolve.
      store_line = written.lines.find { |line| line.start_with?("storeFile=") }.to_s.strip
      resolved = store_line.delete_prefix("storeFile=")
      assert_equal File.realpath(File.join(dir, "upload.jks")), File.realpath(resolved)
    end
  end

  def test_android_signing_prefers_the_environment
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "android"))
      keystore = File.join(dir, "ci.jks")
      File.write(keystore, "keystore")

      previous = ENV.to_hash
      ENV["RUFLET_ANDROID_KEYSTORE"] = keystore
      ENV["RUFLET_ANDROID_KEYSTORE_PASSWORD"] = "envstore"
      ENV["RUFLET_ANDROID_KEY_ALIAS"] = "ci"
      ENV["RUFLET_ANDROID_KEY_PASSWORD"] = "envkey"
      begin
        Dir.chdir(dir) { builder.send(:apply_android_signing_config, client_dir, "aab") }
      ensure
        %w[RUFLET_ANDROID_KEYSTORE RUFLET_ANDROID_KEYSTORE_PASSWORD RUFLET_ANDROID_KEY_ALIAS RUFLET_ANDROID_KEY_PASSWORD].each do |key|
          previous.key?(key) ? ENV[key] = previous[key] : ENV.delete(key)
        end
      end

      written = File.read(File.join(client_dir, "android", "key.properties"))
      assert_includes written, "keyAlias=ci"
      store_line = written.lines.find { |line| line.start_with?("storeFile=") }.to_s.strip
      assert_equal File.realpath(keystore), File.realpath(store_line.delete_prefix("storeFile="))
    end
  end

  def test_android_signing_absent_leaves_no_stale_key_properties
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "build", "client")
      FileUtils.mkdir_p(File.join(client_dir, "android"))
      stale = File.join(client_dir, "android", "key.properties")
      File.write(stale, "storePassword=old\n")

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out
      Dir.chdir(dir) { builder.send(:apply_android_signing_config, client_dir, "aab") }

      refute_path_exists stale
      assert_includes out.string, "will use the debug key"
    ensure
      $stdout = original_stdout
    end
  end

  def test_key_properties_is_never_embedded_in_the_app
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "android"))
      File.write(File.join(dir, "android", "key.properties"), "storePassword=s3cret\n")
      File.write(File.join(dir, "main.rb"), "puts 1")

      included = Dir.chdir(dir) { builder.send(:project_asset_relative_paths) }

      assert_includes included, "main.rb"
      refute(included.any? { |path| path.end_with?("key.properties") }, "signing passwords must not ship")
    end
  end

  def test_extensions_may_declare_a_git_package
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(
        File.join(client_dir, "pubspec.yaml"),
        "name: ruflet_client\ndependencies:\n  flutter:\n    sdk: flutter\n"
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        "import 'package:flet/flet.dart';\n\nvoid main() {\n  final extensions = <FletExtension>[\n  ];\n}\n"
      )

      config = {
        "extensions" => [
          "charts",
          { "my_package" => { "git" => { "url" => "https://github.com/owner/my_package", "branch" => "main" } } }
        ]
      }
      builder.send(:apply_service_extension_config, client_dir, config, self_contained: true)

      pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
      assert_equal(
        { "git" => { "url" => "https://github.com/owner/my_package", "ref" => "main" } },
        pubspec.dig("dependencies", "my_package")
      )

      main = File.read(File.join(client_dir, "lib", "main.self.dart"))
      assert_includes main, "import 'package:my_package/my_package.dart' as my_package;"
      assert_includes main, "my_package.Extension(),"
    end
  end

  def test_extension_git_entry_accepts_a_bare_url_and_tolerates_plain_names
    builder = DummyBuilder.new

    entries = builder.send(
      :external_extension_entries,
      { "extensions" => [
        "charts",
        { "with_url" => { "url" => "https://github.com/owner/with_url", "tag" => "v1.2.0" } },
        { "local_one" => { "path" => "../local_one" } },
        { "no_source" => { "description" => "not a dependency" } }
      ] }
    )

    names = entries.map { |entry| entry[:name] }
    assert_equal %w[with_url local_one], names
    assert_equal({ "git" => { "url" => "https://github.com/owner/with_url", "ref" => "v1.2.0" } }, entries[0][:dependency])
    assert_equal({ "path" => "../local_one" }, entries[1][:dependency])
  end

  def test_verify_android_generated_assets_warns_when_android_12_splash_is_missing
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      res_dir = File.join(dir, "android", "app", "src", "main", "res")
      FileUtils.mkdir_p(File.join(res_dir, "drawable"))
      FileUtils.mkdir_p(File.join(res_dir, "values-v31"))
      File.write(File.join(res_dir, "drawable", "launch_background.xml"), "<layer-list>splash</layer-list>")
      File.write(File.join(res_dir, "values-v31", "styles.xml"), "<resources><style name=\"LaunchTheme\" /></resources>")

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      ok = builder.send(
        :verify_android_generated_assets,
        dir,
        { has_splash: true, has_icon: false },
        "apk"
      )

      assert_equal false, ok
      assert_includes err.string, "Android 12+ splash screen is missing"
    ensure
      $stderr = original_stderr
    end
  end

  def test_verify_android_generated_assets_passes_when_resources_exist
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      main_dir = File.join(dir, "android", "app", "src", "main")
      res_dir = File.join(main_dir, "res")
      FileUtils.mkdir_p(File.join(res_dir, "drawable"))
      FileUtils.mkdir_p(File.join(res_dir, "values-v31"))
      FileUtils.mkdir_p(File.join(res_dir, "mipmap-anydpi-v26"))
      File.write(File.join(res_dir, "drawable", "launch_background.xml"), "<layer-list>splash</layer-list>")
      File.write(
        File.join(res_dir, "values-v31", "styles.xml"),
        "<resources><item name=\"android:windowSplashScreenBackground\">@color/x</item></resources>"
      )
      File.write(File.join(res_dir, "mipmap-anydpi-v26", "launcher_icon.xml"), "<adaptive-icon />")
      File.write(File.join(main_dir, "AndroidManifest.xml"), "<application android:icon=\"@mipmap/launcher_icon\" />")

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      ok = builder.send(
        :verify_android_generated_assets,
        dir,
        { has_splash: true, has_icon: true },
        "aab"
      )

      assert_equal true, ok
      assert_includes out.string, "Android launcher icon and splash resources verified"
    ensure
      $stdout = original_stdout
    end
  end

  def test_prepare_flutter_client_announces_and_runs_asset_generators
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:apply_build_config) do |_client_dir, _config|
        {
          has_icon: true,
          has_splash: true,
          using_default_icon: true,
          using_default_splash: false,
          error: nil
        }
      end

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir }
        true
      end

      out = StringIO.new
      original_stdout = $stdout
      $stdout = out

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "android",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: services_app_config,
        self_contained: false,
        verbose: false
      )

      assert_equal true, result
      assert_includes out.string, "Splash screen is configured"
      assert_includes out.string, "Launcher icons will use the default template asset"
      assert_includes out.string, "Generating splash screen with flutter_native_splash"
      assert_includes out.string, "Generating launcher icons with flutter_launcher_icons"
      assert_equal ["flutter", "precache", "--android"], calls[0][:args]
      assert_equal ["flutter", "pub", "get"], calls[1][:args]
      assert_equal ["dart", "run", "change_app_package_name:main", "com.example.test_app", "--android"], calls[2][:args]
      assert_equal ["dart", "run", "flutter_native_splash:create"], calls[3][:args]
      assert_equal ["dart", "run", "flutter_launcher_icons"], calls[4][:args]
    ensure
      $stdout = original_stdout
    end
  end

  def test_prepare_flutter_client_precaches_android_platform_before_pub_get
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir }
        true
      end

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "apk",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: true,
        verbose: false
      )

      assert_equal true, result
      assert_equal ["flutter", "precache", "--android"], calls[0][:args]
      assert_equal ["flutter", "pub", "get"], calls[1][:args]
      assert_equal client_dir, calls[0][:chdir]
    end
  end

  def test_prepare_flutter_client_stops_when_platform_precache_fails
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir }
        args != ["flutter", "precache", "--android"]
      end

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "android",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: false,
        verbose: false
      )

      assert_equal false, result
      assert_equal [["flutter", "precache", "--android"]], calls.map { |call| call[:args] }
      assert_includes err.string, "Flutter platform artifact setup failed for android"
    ensure
      $stderr = original_stderr
    end
  end

  def test_sync_client_metadata_updates_platform_files_from_ruflet_config
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "android", "app", "src", "main"))
      FileUtils.mkdir_p(
        File.join(client_dir, "android", "app", "src", "main", "kotlin", "com", "example", "ruflet_client")
      )
      FileUtils.mkdir_p(File.join(client_dir, "ios", "Runner"))
      FileUtils.mkdir_p(File.join(client_dir, "ios", "Runner.xcodeproj"))
      FileUtils.mkdir_p(File.join(client_dir, "macos", "Runner", "Configs"))
      FileUtils.mkdir_p(File.join(client_dir, "web"))
      FileUtils.mkdir_p(File.join(client_dir, "windows", "runner"))
      FileUtils.mkdir_p(File.join(client_dir, "linux"))

      File.write(
        File.join(client_dir, "pubspec.yaml"),
        <<~YAML
          name: ruflet_client
          description: "A new Flutter project."
          version: 1.0.0+1
        YAML
      )
      File.write(
        File.join(client_dir, "android", "app", "build.gradle.kts"),
        <<~KTS
          android {
              namespace = "com.example.ruflet_client"
              defaultConfig {
                  applicationId = "com.example.ruflet_client"
              }
          }
        KTS
      )
      File.write(
        File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml"),
        <<~XML
          <application android:label="Ruflet Demo"></application>
        XML
      )
      File.write(
        File.join(
          client_dir, "android", "app", "src", "main", "kotlin", "com", "example", "ruflet_client", "MainActivity.kt"
        ),
        "package com.example.ruflet_client\n"
      )
      File.write(
        File.join(client_dir, "ios", "Runner", "Info.plist"),
        <<~PLIST
          <plist><dict>
          <key>CFBundleDisplayName</key><string>Ruflet Demo</string>
          <key>CFBundleName</key><string>Ruflet Demo</string>
          </dict></plist>
        PLIST
      )
      File.write(
        File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj"),
        <<~PBX
          INFOPLIST_KEY_CFBundleDisplayName = "Ruflet Demo";
          PRODUCT_BUNDLE_IDENTIFIER = com.example.ruflet_client;
          PRODUCT_BUNDLE_IDENTIFIER = com.example.ruflet_client.RunnerTests;
        PBX
      )
      File.write(
        File.join(client_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig"),
        <<~XCCONFIG
          PRODUCT_NAME = ruflet_client
          PRODUCT_BUNDLE_IDENTIFIER = com.example.rubyNativeClient
          PRODUCT_COPYRIGHT = Copyright © 2026 com.example. All rights reserved.
        XCCONFIG
      )
      File.write(
        File.join(client_dir, "web", "manifest.json"),
        <<~JSON
          {"name":"ruflet_client","short_name":"ruflet_client","description":"A new Flutter project."}
        JSON
      )
      File.write(
        File.join(client_dir, "web", "index.html"),
        <<~HTML
          <meta name="description" content="A new Flutter project.">
          <meta name="apple-mobile-web-app-title" content="ruflet_client">
          <title>ruflet_client</title>
        HTML
      )
      File.write(
        File.join(client_dir, "windows", "CMakeLists.txt"),
        <<~CMAKE
          project(ruflet_client LANGUAGES CXX)
          set(BINARY_NAME "ruflet_client")
        CMAKE
      )
      File.write(
        File.join(client_dir, "windows", "runner", "Runner.rc"),
        <<~RC
          VALUE "CompanyName", "com.example" "\\0"
          VALUE "FileDescription", "ruflet_client" "\\0"
          VALUE "InternalName", "ruflet_client" "\\0"
          VALUE "LegalCopyright", "Copyright (C) 2026 com.example. All rights reserved." "\\0"
          VALUE "OriginalFilename", "ruflet_client.exe" "\\0"
          VALUE "ProductName", "ruflet_client" "\\0"
        RC
      )
      File.write(
        File.join(client_dir, "linux", "CMakeLists.txt"),
        <<~CMAKE
          set(BINARY_NAME "ruflet_client")
          set(APPLICATION_ID "com.example.ruflet_client")
        CMAKE
      )

      builder.send(
        :sync_client_metadata,
        client_dir,
        {
          "app" => {
            "name" => "Test App",
            "package_name" => "test_app",
            "organization" => "com.acme",
            "description" => "Configured by ruflet",
            "version" => "2.3.4+5"
          }
        },
        verbose: false
      )

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      assert_includes pubspec, "name: test_app"
      assert_includes pubspec, "description: Configured by ruflet"
      assert_includes pubspec, "version: 2.3.4+5"

      android_gradle = File.read(File.join(client_dir, "android", "app", "build.gradle.kts"))
      assert_includes android_gradle, 'namespace = "com.example.ruflet_client"'
      assert_includes android_gradle, 'applicationId = "com.example.ruflet_client"'
      android_activity = Dir.glob(
        File.join(client_dir, "android", "app", "src", "main", "kotlin", "**", "MainActivity.kt")
      ).first
      assert_includes File.read(android_activity), "package com.example.ruflet_client"
      assert_includes File.read(File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")), 'android:label="Test App"'

      ios_info = File.read(File.join(client_dir, "ios", "Runner", "Info.plist"))
      assert_includes ios_info, "<string>Test App</string>"
      ios_project = File.read(File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj"))
      assert_includes ios_project, 'INFOPLIST_KEY_CFBundleDisplayName = "Test App";'
      assert_includes ios_project, "PRODUCT_BUNDLE_IDENTIFIER = com.example.ruflet_client;"
      assert_includes ios_project, "PRODUCT_BUNDLE_IDENTIFIER = com.example.ruflet_client.RunnerTests;"

      macos_info = File.read(File.join(client_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig"))
      assert_includes macos_info, "PRODUCT_NAME = Test App"
      assert_includes macos_info, "PRODUCT_BUNDLE_IDENTIFIER = com.acme.test-app"

      web_manifest = File.read(File.join(client_dir, "web", "manifest.json"))
      assert_includes web_manifest, '"name": "Test App"'
      assert_includes web_manifest, '"short_name": "Test App"'

      web_index = File.read(File.join(client_dir, "web", "index.html"))
      assert_includes web_index, '<title>Test App</title>'
      assert_includes web_index, 'content="Configured by ruflet"'

      windows_cmake = File.read(File.join(client_dir, "windows", "CMakeLists.txt"))
      assert_includes windows_cmake, "project(test_app LANGUAGES CXX)"
      assert_includes windows_cmake, 'set(BINARY_NAME "test_app")'

      windows_rc = File.read(File.join(client_dir, "windows", "runner", "Runner.rc"))
      assert_includes windows_rc, 'VALUE "CompanyName", "com.acme" "\\0"'
      assert_includes windows_rc, 'VALUE "ProductName", "Test App" "\\0"'

      linux_cmake = File.read(File.join(client_dir, "linux", "CMakeLists.txt"))
      assert_includes linux_cmake, 'set(BINARY_NAME "test_app")'
      assert_includes linux_cmake, 'set(APPLICATION_ID "com.acme.test_app")'
    end
  end

  def test_prepare_flutter_client_applies_mobile_package_name_after_pub_get
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(client_dir)
      metadata = {
        android_application_id: "com.acme.test_app",
        ios_bundle_identifier: "com.acme.test_app",
        mobile_identity_errors: []
      }

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| metadata }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir }
        true
      end

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "apk",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: true,
        verbose: false
      )

      assert_equal true, result
      assert_equal ["flutter", "precache", "--android"], calls[0][:args]
      assert_equal ["flutter", "pub", "get"], calls[1][:args]
      assert_equal(
        ["dart", "run", "change_app_package_name:main", "com.acme.test_app", "--android"],
        calls[2][:args]
      )
      assert_equal client_dir, calls[2][:chdir]
    end
  end

  def test_prepare_flutter_client_rejects_a_mobile_build_without_an_app_identity
    builder = DummyBuilder.new

    Dir.mktmpdir do |client_dir|
      metadata = {
        mobile_identity_errors: ["app.app_name", "app.package_name", "app.organization", "services.yaml app section"]
      }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| metadata }
      builder.define_singleton_method(:system) { |*| flunk "Flutter commands must not run without app identity" }

      stderr = StringIO.new
      original_stderr = $stderr
      $stderr = stderr
      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "apk",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: true,
        verbose: false
      )

      assert_equal false, result
      assert_includes stderr.string, "ruflet.yaml must define"
      assert_includes stderr.string, "app.name"
      assert_includes stderr.string, "app.package_name"
      assert_includes stderr.string, "app.organization"
    ensure
      $stderr = original_stderr
    end
  end

  def test_prepare_flutter_client_runs_pod_install_for_ios
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      ios_dir = File.join(client_dir, "ios")
      FileUtils.mkdir_p(ios_dir)
      File.write(File.join(ios_dir, "Podfile"), "platform :ios, '13.0'\n")

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir, env: _env }
        true
      end

      original_bundle_gemfile = ENV["BUNDLE_GEMFILE"]
      ENV["BUNDLE_GEMFILE"] = "/tmp/example/Gemfile"

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "ios",
        tools: { env: { "BUNDLE_GEMFILE" => "/tmp/example/Gemfile", "PATH" => "/tmp/bin" }, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: false,
        verbose: false
      )

      assert_equal true, result
      assert_equal ["flutter", "precache", "--ios"], calls[0][:args]
      assert_equal ["flutter", "pub", "get"], calls[1][:args]
      assert_equal client_dir, calls[0][:chdir]
      assert_equal ["pod", "install"], calls[2][:args]
      assert_equal ios_dir, calls[2][:chdir]
      refute calls[2][:env].key?("BUNDLE_GEMFILE")
      assert_equal "/tmp/bin", calls[2][:env]["PATH"]
    ensure
      ENV["BUNDLE_GEMFILE"] = original_bundle_gemfile
    end
  end

  def test_prepare_flutter_client_stops_when_pod_install_fails
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      ios_dir = File.join(client_dir, "ios")
      FileUtils.mkdir_p(ios_dir)
      File.write(File.join(ios_dir, "Podfile"), "platform :ios, '13.0'\n")

      builder.define_singleton_method(:apply_service_extension_config) { |_client_dir, _config| nil }
      builder.define_singleton_method(:configure_client_runtime_mode) { |_client_dir, self_contained:, verbose: false| nil }
      builder.define_singleton_method(:sync_client_metadata) { |_client_dir, _config, verbose: false| nil }
      builder.define_singleton_method(:apply_build_config) { |_client_dir, _config| { has_icon: false, has_splash: false, error: nil } }

      calls = []
      builder.define_singleton_method(:system) do |_env, *args, chdir: nil|
        calls << { args: args, chdir: chdir }
        args != ["pod", "install"]
      end

      err = StringIO.new
      original_stderr = $stderr
      $stderr = err

      result = builder.send(
        :prepare_flutter_client,
        client_dir,
        platform: "ios",
        tools: { env: {}, flutter: "flutter", dart: "dart" },
        config: {},
        self_contained: false,
        verbose: false
      )

      assert_equal false, result
      assert_equal ["pod", "install"], calls[2][:args]
      assert_includes err.string, "CocoaPods install failed for ios"
    ensure
      $stderr = original_stderr
    end
  end

  def test_prune_client_main_removes_multiline_optional_service_imports_and_extensions
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      main_path = File.join(dir, "main.self.dart")
      File.write(
        main_path,
        <<~DART
          import 'package:flet/flet.dart';
          import 'package:flet_audio_recorder/flet_audio_recorder.dart'
              as ruflet_audio_recorder;
          import 'package:flet_color_pickers/flet_color_pickers.dart'
              as ruflet_color_picker;
          import 'package:flet_secure_storage/flet_secure_storage.dart'
              as ruflet_secure_storage;
          import 'ruflet_webview.dart' as ruflet_webview;

          final extensions = <FletExtension>[
            ruflet_audio_recorder.Extension(),
            ruflet_color_picker.Extension(),
            ruflet_secure_storage.Extension(),
            ruflet_webview.RufletWebViewExtension(),
          ];
        DART
      )

      builder.send(:prune_client_main, main_path, [])

      content = File.read(main_path)
      refute_includes content, "flet_audio_recorder"
      refute_includes content, "flet_color_pickers"
      refute_includes content, "flet_secure_storage"
      refute_includes content, "ruflet_webview.dart"
      refute_includes content, "ruflet_audio_recorder.Extension()"
      refute_includes content, "ruflet_color_picker.Extension()"
      refute_includes content, "ruflet_secure_storage.Extension()"
      refute_includes content, "ruflet_webview.RufletWebViewExtension()"
      assert_includes content, "import 'package:flet/flet.dart';"
    end
  end

end
