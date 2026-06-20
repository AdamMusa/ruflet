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

  def test_github_json_falls_back_to_curl_when_ruby_ssl_fails
    updater = DummyUpdater.new
    test_case = self
    updater.define_singleton_method(:curl_get) do |url, headers: []|
      test_case.assert_equal "https://example.test/release", url
      test_case.assert_includes headers, "Accept: application/vnd.github+json"
      { "tag_name" => "Alpha", "assets" => [] }.to_json
    end

    with_net_http_ssl_failure do
      release = updater.send(:github_get_json, "https://example.test/release")

      assert_equal "Alpha", release["tag_name"]
    end
  end

  def test_download_file_falls_back_to_curl_when_ruby_ssl_fails
    updater = DummyUpdater.new

    Dir.mktmpdir do |dir|
      destination = File.join(dir, "client.tar.gz")
      test_case = self
      updater.define_singleton_method(:curl_download) do |url, path|
        test_case.assert_equal "https://example.test/client.tar.gz", url
        File.write(path, "archive")
        path
      end

      with_net_http_ssl_failure do
        updater.send(:download_file, "https://example.test/client.tar.gz", destination)
      end

      assert_equal "archive", File.read(destination)
    end
  end

  def test_new_app_gemfile_uses_current_runtime_package_versions
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_core", ">= #{Ruflet::VERSION}")
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, %(gem "ruflet_server", ">= #{Ruflet::VERSION}")
    refute_includes Ruflet::CLI::GEMFILE_TEMPLATE, "0.0.10"
  end

  def test_prepare_flutter_client_uses_template_ruby_runtime_dependency
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
            ruby_runtime: ^0.0.4
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
      repo_plugin = File.expand_path("../../../ruby_runtime", __dir__)
      assert_equal({ "path" => repo_plugin }, ruby_runtime,
                   "repo checkouts should build against the local plugin")
      assert_includes calls, client_dir
    end
  end

  def test_ruby_runtime_dependency_uses_hosted_template_requirement
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      FileUtils.mkdir_p(template_dir)
      File.write(
        File.join(template_dir, "pubspec.yaml"),
        "dependencies:\n  ruby_runtime: ^0.0.5\n"
      )
      with_template_root(template_dir) do
        dependency = builder.send(:ruby_runtime_dependency, "^0.0.3")
        assert_equal "^0.0.5", dependency
      end
    end
  end

  def test_ruby_runtime_dependency_never_copies_relative_template_paths
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      FileUtils.mkdir_p(template_dir)
      File.write(
        File.join(template_dir, "pubspec.yaml"),
        "dependencies:\n  ruby_runtime:\n    path: ../../../ruby_runtime\n"
      )
      with_template_root(template_dir) do
        dependency = builder.send(:ruby_runtime_dependency, nil)
        assert_equal Ruflet::CLI::BuildCommand::RUBY_RUNTIME_FALLBACK_REQUIREMENT, dependency
      end
    end
  end

  def test_ruby_runtime_dependency_uses_local_plugin_in_repo_checkout
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(template_dir)
      File.write(File.join(template_dir, "pubspec.yaml"), "dependencies:\n  ruby_runtime: ^0.0.5\n")
      plugin_dir = File.join(dir, "ruby_runtime")
      FileUtils.mkdir_p(plugin_dir)
      File.write(File.join(plugin_dir, "pubspec.yaml"), "name: ruby_runtime\n")

      with_template_root(template_dir) do
        dependency = builder.send(:ruby_runtime_dependency, "^0.0.3")
        assert_equal({ "path" => plugin_dir }, dependency)
      end
    end
  end

  def with_template_root(template_dir)
    original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
    Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
    Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
    yield
  ensure
    Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
    Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
  end

  def test_sync_self_contained_project_assets_normalizes_endless_methods
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      File.write(File.join(dir, "main.rb"), "def title = \"Ruflet\"\n")

      Dir.chdir(dir) do
        builder.send(:sync_self_contained_project_assets, client_dir)
      end

      copied = File.read(File.join(client_dir, "assets", File.basename(dir), "main.rb"))
      assert_includes copied, "def title\n"
      assert_includes copied, "\"Ruflet\"\n"
      assert_includes copied, "end\n"
      refute_includes copied, "def title ="
    end
  end

  def test_sync_self_contained_project_assets_bundles_entrypoint_require_relative
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir, "assets"))
      FileUtils.mkdir_p(File.join(dir, "lib"))
      File.write(File.join(dir, "main.rb"), "require_relative \"lib/app\"\nDemoApp.new.run\n")
      File.write(File.join(dir, "lib", "app.rb"), "class DemoApp\nend\n")

      Dir.chdir(dir) do
        builder.send(:sync_self_contained_project_assets, client_dir)
      end

      copied = File.read(File.join(client_dir, "assets", File.basename(dir), "main.rb"))
      refute_includes copied, "require_relative"
      assert_includes copied, "class DemoApp"
      assert_includes copied, "DemoApp.new.run"
    end
  end

  def test_self_contained_pubspec_lists_nested_project_assets
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      client_dir = File.join(dir, "ruflet_client")
      FileUtils.mkdir_p(File.join(client_dir))
      FileUtils.mkdir_p(File.join(dir, "standalone_apps", "counter"))
      File.write(File.join(dir, "main.rb"), "Ruflet.run {}\n")
      File.write(File.join(dir, "standalone_apps", "counter", "main.rb"), "Ruflet.run {}\n")
      File.write(File.join(client_dir, "pubspec.yaml"), "dependencies: {}\nflutter: {}\n")

      Dir.chdir(dir) do
        builder.send(:sync_client_pubspec_for_runtime_mode, client_dir, self_contained: true)
      end

      assets = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml"))).dig("flutter", "assets")
      prefix = "assets/#{File.basename(dir)}/"
      assert_includes assets, "#{prefix}main.rb"
      assert_includes assets, "#{prefix}standalone_apps/counter/main.rb"
      refute_includes assets, prefix
    end
  end

  def test_rive_extension_uses_flet_flutter_extension
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      pubspec = File.join(dir, "pubspec.yaml")
      File.write(pubspec, "dependencies:\n  rive: any\n  rive_native: any\n")
      template_dir = File.expand_path("../../../templates/ruflet_flutter_template", __dir__)

      with_template_root(template_dir) do
        builder.send(:sync_client_extension_dependencies, pubspec, ["flet_rive"])
      end

      dependencies = YAML.safe_load(File.read(pubspec)).fetch("dependencies")
      assert dependencies.key?("flet_rive")
      refute dependencies.key?("rive")
      refute dependencies.key?("rive_native")
    end
  end

  def test_rive_extension_does_not_require_native_linker_overrides
    template_dir = File.expand_path("../../../templates/ruflet_flutter_template", __dir__)
    podfile = File.read(File.join(template_dir, "ios", "Podfile"))
    template_pubspec = YAML.safe_load(
      File.read(File.join(template_dir, "pubspec.yaml")),
      aliases: true
    )

    assert template_pubspec.dig("dependencies", "flet_rive")
    refute template_pubspec.dig("dependencies", "rive_native")
    refute_includes podfile, "rive_native"
    refute_includes podfile, "force_load"
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
            ruby_runtime: ^0.0.4
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
        config: {},
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
            "assets" => ["assets/showcase/"]
          }
        }
      )

      pubspec = File.read(path)
      assert_includes pubspec, "  assets:\n    - assets/showcase/"
      refute_includes pubspec, "  assets:\n- assets/showcase/"
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

  def test_configured_extensions_install_flutter_extensions
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
            flet:
              path: flet_packages/flet
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
      File.write(File.join(client_dir, "services.yaml"), "services:\n  - webview\n")

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:apply_service_extension_config, client_dir, { "extensions" => ["webview"] }, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        assert pubspec.dig("dependencies", "flet_webview")
        assert_equal(
          { "path" => "flet_packages/flet" },
          pubspec.dig("dependency_overrides", "flet")
        )

        main = File.read(File.join(client_dir, "lib", "main.self.dart"))
        assert_includes main, "package:flet_webview/flet_webview.dart"
        assert_includes main, "ruflet_webview.Extension(),"
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_generated_client_keeps_only_selected_local_flet_packages_and_restores_new_selections
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      package_names = %w[flet flet_camera flet_permission_handler flet_webview]
      package_names.each do |package_name|
        source = File.join(template_dir, "flet_packages", package_name)
        target = File.join(client_dir, "flet_packages", package_name)
        FileUtils.mkdir_p(source)
        File.write(File.join(source, "pubspec.yaml"), "name: #{package_name}\n")
        FileUtils.mkdir_p(target)
        File.write(File.join(target, "pubspec.yaml"), "name: #{package_name}\n")
      end

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:sync_client_flet_packages, client_dir, ["flet_webview"])

        assert_path_exists File.join(client_dir, "flet_packages", "flet")
        assert_path_exists File.join(client_dir, "flet_packages", "flet_webview")
        refute_path_exists File.join(client_dir, "flet_packages", "flet_camera")
        refute_path_exists File.join(client_dir, "flet_packages", "flet_permission_handler")

        builder.send(:sync_client_flet_packages, client_dir, %w[flet_camera flet_permission_handler])

        assert_path_exists File.join(client_dir, "flet_packages", "flet")
        assert_path_exists File.join(client_dir, "flet_packages", "flet_camera")
        assert_path_exists File.join(client_dir, "flet_packages", "flet_permission_handler")
        refute_path_exists File.join(client_dir, "flet_packages", "flet_webview")
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_standalone_ruflet_client_keeps_full_local_flet_package_catalog
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "templates", "ruflet_flutter_template")
      client_dir = File.join(dir, "ruflet_client")
      %w[flet flet_camera flet_webview].each do |package_name|
        FileUtils.mkdir_p(File.join(template_dir, "flet_packages", package_name))
        FileUtils.mkdir_p(File.join(client_dir, "flet_packages", package_name))
      end

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:sync_client_flet_packages, client_dir, [])

        assert_path_exists File.join(client_dir, "flet_packages", "flet_camera")
        assert_path_exists File.join(client_dir, "flet_packages", "flet_webview")
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_refresh_managed_client_template_files_refreshes_macos_entitlements
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(template_dir, "macos", "Runner"))
      FileUtils.mkdir_p(File.join(client_dir, "macos", "Runner"))

      File.write(
        File.join(template_dir, "macos", "Runner", "Release.entitlements"),
        "<plist><dict><key>com.apple.security.files.user-selected.read-write</key><true/></dict></plist>\n"
      )
      FileUtils.mkdir_p(File.join(template_dir, "lib"))
      File.write(File.join(template_dir, "lib", "ruflet_file_picker_service.dart"), "class RufletFilePickerExtension {}\n")
      File.write(
        File.join(client_dir, "macos", "Runner", "Release.entitlements"),
        "<plist><dict></dict></plist>\n"
      )
      FileUtils.mkdir_p(File.join(client_dir, "lib"))

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:refresh_managed_client_template_files, client_dir, verbose: false)

        refreshed = File.read(File.join(client_dir, "macos", "Runner", "Release.entitlements"))
        assert_includes refreshed, "com.apple.security.files.user-selected.read-write"
        assert_equal(
          "class RufletFilePickerExtension {}\n",
          File.read(File.join(client_dir, "lib", "ruflet_file_picker_service.dart"))
        )
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_refresh_managed_client_template_files_repairs_legacy_self_contained_bootstrap
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(template_dir, "lib"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(
        File.join(template_dir, "lib", "main.self.dart"),
        <<~DART
          await RubyRuntime.initialize();
          await RubyRuntime.eval("ENV['RUFLET_DEBUG'] ||= '1'; 'debug enabled'");
          final digestLength = await RubyRuntime.eval(
            "require 'digest/sha1'; Digest::SHA1.digest('abc').bytesize.to_s",
          );
          debugPrint('Embedded Digest::SHA1 bytesize: $digestLength');
          await RubyRuntime.startFileServer(serverPath);
        DART
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        "await RubyRuntime.initialize();\nawait RubyRuntime.eval(\"ENV['RUFLET_DEBUG'] ||= '1'\");\n"
      )

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:refresh_managed_client_template_files, client_dir, verbose: false)

        refreshed = File.read(File.join(client_dir, "lib", "main.self.dart"))
        assert_includes refreshed, "RubyRuntime.startFileServer"
        refute_includes refreshed, "RubyRuntime.eval"
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_self_contained_service_extension_config_does_not_add_unconfigured_extensions
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
      File.write(File.join(client_dir, "services.yaml"), "services: []\n")

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:apply_service_extension_config, client_dir, {}, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        refute pubspec.dig("dependencies", "flet_webview")

        main = File.read(File.join(client_dir, "lib", "main.self.dart"))
        refute_includes main, "package:flet_webview/flet_webview.dart"
        refute_includes main, "ruflet_webview.Extension(),"
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_configured_extensions_and_services_can_enable_every_known_extension
    builder = DummyBuilder.new
    extension_map = Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(template_dir, "lib"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))

      template_dependencies = extension_map.values.map { |meta| "            #{meta[:package]}: any\n" }.join
      template_imports = extension_map.values.map do |meta|
        "          import 'package:#{meta[:package]}/#{meta[:package]}.dart' as #{meta[:alias]};\n"
      end.join
      template_extensions = extension_map.values.map { |meta| "              #{meta[:alias]}.Extension(),\n" }.join

      File.write(
        File.join(template_dir, "pubspec.yaml"),
        <<~YAML
          dependencies:
            flutter:
              sdk: flutter
            flet: any
#{template_dependencies}
        YAML
      )
      File.write(
        File.join(template_dir, "lib", "main.self.dart"),
        <<~DART
          import 'package:flet/flet.dart';
#{template_imports}
          void main() {
            final extensions = <FletExtension>[
#{template_extensions}
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
      File.write(
        File.join(client_dir, "services.yaml"),
        YAML.dump("services" => %w[camera microphone location])
      )

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:apply_service_extension_config, client_dir, { "extensions" => extension_map.keys }, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        main = File.read(File.join(client_dir, "lib", "main.self.dart"))
        extension_map.values.each do |meta|
          assert pubspec.dig("dependencies", meta[:package]), "Expected #{meta[:package]} dependency"
          assert_includes main, "package:#{meta[:package]}/#{meta[:package]}.dart"
          assert_includes main, "#{meta[:alias]}.Extension(),"
        end
      ensure
        Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root, original_method)
        Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)
      end
    end
  end

  def test_service_backed_extension_declarations_are_ignored_without_services
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      template_dir = File.join(dir, "template")
      client_dir = File.join(dir, "client")
      FileUtils.mkdir_p(File.join(template_dir, "lib"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))
      File.write(File.join(template_dir, "pubspec.yaml"), "dependencies:\n  flutter:\n    sdk: flutter\n  flet: any\n  flet_camera: any\n")
      File.write(File.join(template_dir, "lib", "main.self.dart"), "import 'package:flet_camera/flet_camera.dart' as ruflet_camera;\nfinal extensions = [ruflet_camera.Extension(),];\n")
      File.write(File.join(client_dir, "pubspec.yaml"), "dependencies:\n  flutter:\n    sdk: flutter\n  flet: any\n")
      File.write(File.join(client_dir, "lib", "main.self.dart"), "final extensions = [];\n")
      File.write(File.join(client_dir, "services.yaml"), "services: []\n")

      original_method = Ruflet::CLI.method(:resolve_ruflet_client_template_root)
      Ruflet::CLI.define_singleton_method(:resolve_ruflet_client_template_root) { template_dir }
      Ruflet::CLI.singleton_class.send(:private, :resolve_ruflet_client_template_root)

      begin
        builder.send(:apply_service_extension_config, client_dir, { "extensions" => ["camera"] }, self_contained: true)

        pubspec = YAML.safe_load(File.read(File.join(client_dir, "pubspec.yaml")), aliases: true)
        refute pubspec.dig("dependencies", "flet_camera")
        refute_includes File.read(File.join(client_dir, "lib", "main.self.dart")), "flet_camera"
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
      assert_includes out.string, "[ruflet build] command=flutter build apk --target lib/main.self.dart --dart-define RUFLET_BACKEND_URL=https://api.example.com --dart-define RUFLET_EMBEDDED_PROJECT=ruflet -v"
      assert_equal ["flutter", "build", "apk", "--target", "lib/main.self.dart", "--dart-define", "RUFLET_BACKEND_URL=https://api.example.com", "--dart-define", "RUFLET_EMBEDDED_PROJECT=ruflet", "-v"], calls.first[:args]
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
      builder.define_singleton_method(:select_install_device) do |**_kwargs|
        "BE4BD1A5-E81C-4A73-AA4B-10ADFB63BF0A"
      end

      calls = []
      builder.define_singleton_method(:system) do |_env, *_args, chdir: nil|
        calls << { env: _env, args: _args, chdir: chdir }
        true
      end

      code = builder.command_install([])

      assert_equal 0, code
      assert_equal ["flutter", "install", "-d", "BE4BD1A5-E81C-4A73-AA4B-10ADFB63BF0A"], calls.first[:args]
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
      builder.define_singleton_method(:select_install_device) { |**_kwargs| "macos" }
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

  def test_select_install_device_displays_numbered_choices_and_retries
    builder = DummyBuilder.new
    devices = [
      {
        "name" => "Pixel 9",
        "id" => "emulator-5554",
        "targetPlatform" => "android-arm64",
        "emulator" => true,
        "isSupported" => true
      },
      {
        "name" => "Adam's iPhone",
        "id" => "00008140-0019590E3C87001C",
        "targetPlatform" => "ios",
        "emulator" => false,
        "isSupported" => true
      }
    ]
    builder.define_singleton_method(:discover_install_devices) { |**_kwargs| devices }
    input = StringIO.new("9\n2\n")
    output = StringIO.new

    selected = builder.send(
      :select_install_device,
      flutter: "flutter",
      env: {},
      client_dir: "/tmp/client",
      input: input,
      output: output
    )

    assert_equal "00008140-0019590E3C87001C", selected
    assert_includes output.string, "1) Pixel 9 (android-arm64, emulator) [emulator-5554]"
    assert_includes output.string, "2) Adam's iPhone (ios, physical) [00008140-0019590E3C87001C]"
    assert_includes output.string, "Enter a number from 1 to 2."
  end

  def test_discover_install_devices_uses_flutter_machine_output
    builder = DummyBuilder.new

    Dir.mktmpdir do |dir|
      flutter = File.join(dir, "flutter")
      File.write(flutter, <<~SH)
        #!/bin/sh
        printf '%s' '[{"name":"Phone","id":"phone-1","targetPlatform":"ios","isSupported":true},{"name":"Unsupported","id":"old-1","isSupported":false}]'
      SH
      FileUtils.chmod("+x", flutter)

      devices = builder.send(
        :discover_install_devices,
        flutter: flutter,
        env: {},
        client_dir: dir
      )

      assert_equal ["phone-1"], devices.map { |device| device["id"] }
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
      assert_equal ["flutter", "precache", "--android"], calls[0][:args]
      assert_equal ["flutter", "pub", "get"], calls[1][:args]
      assert_equal ["dart", "run", "flutter_native_splash:create"], calls[2][:args]
      assert_equal ["dart", "run", "flutter_launcher_icons"], calls[3][:args]
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
      FileUtils.mkdir_p(File.join(client_dir, "ios", "Runner"))
      FileUtils.mkdir_p(File.join(client_dir, "ios", "Runner.xcodeproj"))
      FileUtils.mkdir_p(File.join(client_dir, "macos", "Runner", "Configs"))
      FileUtils.mkdir_p(File.join(client_dir, "web"))
      FileUtils.mkdir_p(File.join(client_dir, "windows", "runner"))
      FileUtils.mkdir_p(File.join(client_dir, "linux"))
      FileUtils.mkdir_p(File.join(client_dir, "lib"))

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
      File.write(
        File.join(client_dir, "lib", "main.server.dart"),
        <<~DART
          return FletApp(
            title: 'Ruflet',
          );
        DART
      )
      File.write(
        File.join(client_dir, "lib", "main.self.dart"),
        <<~DART
          return MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Ruflet')),
            ),
          );

          return FletApp(
            title: 'Ruflet',
          );
        DART
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

      server_dart = File.read(File.join(client_dir, "lib", "main.server.dart"))
      assert_includes server_dart, "title: 'Test App'"

      self_dart = File.read(File.join(client_dir, "lib", "main.self.dart"))
      assert_includes self_dart, "title: 'Test App'"
      assert_includes self_dart, "AppBar(title: const Text('Test App'))"
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

  private

  def with_net_http_ssl_failure
    singleton = class << Net::HTTP; self; end
    original = Net::HTTP.method(:start)
    singleton.define_method(:start) do |*|
      raise OpenSSL::SSL::SSLError, "certificate verify failed"
    end
    yield
  ensure
    singleton.define_method(:start, original) if original
  end
end
