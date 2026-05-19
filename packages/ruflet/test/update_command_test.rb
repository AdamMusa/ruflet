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

  def test_command_update_check_reports_manifest_status
    updater = DummyUpdater.new
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "web"))
      File.write(File.join(dir, "web", "index.html"), "<html></html>")

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

  def test_prepare_flutter_client_uses_local_ruby_runtime_dependency_when_available
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
        config: {},
        self_contained: true,
        verbose: false
      )

      refute_path_exists File.join(client_dir, "pubspec_overrides.yaml")
      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      ruby_runtime = YAML.safe_load(pubspec, aliases: true).dig("dependencies", "ruby_runtime")
      assert_kind_of Hash, ruby_runtime
      assert_path_exists File.join(ruby_runtime.fetch("path"), "pubspec.yaml")
      assert_includes calls, client_dir
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
          flutter:
            assets:
              - assets/demo/
        YAML
      )

      builder.send(:prune_client_pubspec, path, [])

      pubspec = File.read(path)
      assert_includes pubspec, "  assets:\n    - assets/demo/"
      refute_includes pubspec, "  assets:\n- assets/demo/"
    end
  end

  def test_self_contained_service_extension_config_restores_full_client_extensions
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
            flet_webview:
              git:
                url: https://example.com/ruflet.git
                path: webview
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
        builder.send(:apply_service_extension_config, client_dir, {}, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        assert pubspec.dig("dependencies", "flet_webview")

        main = File.read(File.join(client_dir, "lib", "main.self.dart"))
        assert_includes main, "package:flet_webview/flet_webview.dart"
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
              - assets/main.rb
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
        config: {},
        self_contained: false,
        verbose: false
      )

      pubspec = File.read(File.join(client_dir, "pubspec.yaml"))
      refute_includes pubspec, "ruby_runtime"
      refute_includes pubspec, "assets/main.rb"
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
      assert_includes out.string, "[ruflet build] command=flutter build apk --target lib/main.self.dart --dart-define RUFLET_BACKEND_URL=https://api.example.com -v"
      assert_equal ["flutter", "build", "apk", "--target", "lib/main.self.dart", "--dart-define", "RUFLET_BACKEND_URL=https://api.example.com", "-v"], calls.first[:args]
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
      assert_equal ["flutter", "build", "ios", "--codesign", "--target", "lib/main.self.dart"], calls.first[:args]
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
    end
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
        config: {},
        self_contained: false,
        verbose: false
      )

      assert_equal true, result
      assert_includes out.string, "Splash screen is configured"
      assert_includes out.string, "Launcher icons will use the default template asset"
      assert_includes out.string, "Generating splash screen with flutter_native_splash"
      assert_includes out.string, "Generating launcher icons with flutter_launcher_icons"
      assert_equal ["flutter", "pub", "get"], calls[0][:args]
      assert_equal ["dart", "run", "flutter_native_splash:create"], calls[1][:args]
      assert_equal ["dart", "run", "flutter_launcher_icons"], calls[2][:args]
    ensure
      $stdout = original_stdout
    end
  end

  def test_sync_client_metadata_updates_platform_files_from_ruflet_config
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "android", "app", "src", "main"))
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
      assert_includes android_gradle, 'namespace = "com.acme.test_app"'
      assert_includes android_gradle, 'applicationId = "com.acme.test_app"'
      assert_includes File.read(File.join(client_dir, "android", "app", "src", "main", "AndroidManifest.xml")), 'android:label="Test App"'

      ios_info = File.read(File.join(client_dir, "ios", "Runner", "Info.plist"))
      assert_includes ios_info, "<string>Test App</string>"
      ios_project = File.read(File.join(client_dir, "ios", "Runner.xcodeproj", "project.pbxproj"))
      assert_includes ios_project, 'INFOPLIST_KEY_CFBundleDisplayName = "Test App";'
      assert_includes ios_project, "PRODUCT_BUNDLE_IDENTIFIER = com.acme.test_app;"
      assert_includes ios_project, "PRODUCT_BUNDLE_IDENTIFIER = com.example.ruflet_client.RunnerTests;"

      macos_info = File.read(File.join(client_dir, "macos", "Runner", "Configs", "AppInfo.xcconfig"))
      assert_includes macos_info, "PRODUCT_NAME = Test App"
      assert_includes macos_info, "PRODUCT_BUNDLE_IDENTIFIER = com.acme.test_app"

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
      assert_equal ["flutter", "pub", "get"], calls[0][:args]
      assert_equal client_dir, calls[0][:chdir]
      assert_equal ["pod", "install"], calls[1][:args]
      assert_equal ios_dir, calls[1][:chdir]
      refute calls[1][:env].key?("BUNDLE_GEMFILE")
      assert_equal "/tmp/bin", calls[1][:env]["PATH"]
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
      assert_equal ["pod", "install"], calls[1][:args]
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

          final extensions = <FletExtension>[
            ruflet_audio_recorder.Extension(),
            ruflet_color_picker.Extension(),
            ruflet_secure_storage.Extension(),
          ];
        DART
      )

      builder.send(:prune_client_main, main_path, [])

      content = File.read(main_path)
      refute_includes content, "flet_audio_recorder"
      refute_includes content, "flet_color_pickers"
      refute_includes content, "flet_secure_storage"
      refute_includes content, "ruflet_audio_recorder.Extension()"
      refute_includes content, "ruflet_color_picker.Extension()"
      refute_includes content, "ruflet_secure_storage.Extension()"
      assert_includes content, "import 'package:flet/flet.dart';"
    end
  end

end
