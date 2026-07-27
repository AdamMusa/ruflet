# frozen_string_literal: true

require_relative "test_helper"

class RufletCliTemplatesTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../../..", __dir__)
  EXPLORER_CONFIG_DIRS = %w[ruflet_client].freeze
  EXPLORER_EXTENSION_REGISTRATIONS = {
    "audio" => "flet_audio.Extension()",
    "audio_recorder" => "flet_audio_recorder.Extension()",
    "camera" => "flet_camera.Extension()",
    "charts" => "flet_charts.Extension()",
    "code_editor" => "flet_code_editor.Extension()",
    "color_pickers" => "flet_color_picker.Extension()",
    "datatable2" => "flet_datatable2.Extension()",
    "flashlight" => "flet_flashlight.Extension()",
    "geolocator" => "flet_geolocator.Extension()",
    "lottie" => "flet_lottie.Extension()",
    "map" => "flet_map.Extension()",
    "permission_handler" => "flet_permission_handler.Extension()",
    "qrcode_scanner" => "ruflet_qrcode_scanner.Extension()",
    "rive" => "flet_rive.Extension()",
    "secure_storage" => "flet_secure_storage.Extension()",
    "video" => "flet_video.Extension()",
    "webview" => "flet_webview.Extension()"
  }.freeze

  def test_main_template_boots_app
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'Ruflet.run do |page|'
    assert_includes Ruflet::CLI::MAIN_TEMPLATE, 'require "ruflet"'
  end

  def test_gemfile_template_includes_runtime_dependencies
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_core"'
    assert_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet_server"'
    refute_includes Ruflet::CLI::GEMFILE_TEMPLATE, 'gem "ruflet",'
  end

  def test_reusable_explorer_does_not_contain_project_configuration
    refute_path_exists repo_file("ruflet_client", "ruflet.yaml")
    refute_path_exists repo_file("ruflet_client", "services.yaml")
  end

  def test_reusable_explorer_registers_every_optional_extension
    expected_extensions = Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP.keys.sort
    source = File.read(repo_file("ruflet_client", "lib/main.dart"))

    assert_equal expected_extensions, EXPLORER_EXTENSION_REGISTRATIONS.keys.sort
    EXPLORER_EXTENSION_REGISTRATIONS.each do |extension, registration|
      assert_includes source, registration, extension
    end
  end

  def test_qrcode_scanner_is_bundled_inside_the_sparse_checkout
    package_root = repo_file("ruflet_client", "flet_packages/ruflet_qrcode_scanner")
    pubspec = YAML.safe_load(File.read(File.join(package_root, "pubspec.yaml")), aliases: true)
    client_pubspec = YAML.safe_load(File.read(repo_file("ruflet_client", "pubspec.yaml")), aliases: true)
    workflow = File.read(repo_file(".github", "workflows/build-ruflet-android.yml"))

    assert_equal "ruflet_qrcode_scanner", pubspec.fetch("name")
    assert_equal({ "path" => "../flet" }, pubspec.dig("dependencies", "flet"))
    assert_equal(
      { "path" => "flet_packages/ruflet_qrcode_scanner" },
      client_pubspec.dig("dependencies", "ruflet_qrcode_scanner")
    )
    assert_includes workflow, "working-directory: ruflet_client/flet_packages/ruflet_qrcode_scanner"
    assert_includes workflow, "needs: validate-extensions"
  end

  def test_spinkit_uses_the_bundled_flet_extension_package
    client_pubspec = YAML.safe_load(File.read(repo_file("ruflet_client", "pubspec.yaml")), aliases: true)
    client_main = File.read(repo_file("ruflet_client", "lib/main.dart"))

    assert_equal(
      { "path" => "flet_packages/flet_spinkit" },
      client_pubspec.dig("dependencies", "flet_spinkit")
    )
    refute client_pubspec.dig("dependencies").key?("flutter_spinkit")
    assert_includes client_main, "flet_spinkit.Extension(),"
    refute_path_exists repo_file("ruflet_client", "lib/ruflet_spinkit.dart")
  end

  def test_template_is_owned_by_external_repository
    assert_equal "https://github.com/AdamMusa/ruflet-template.git", Ruflet::CLI::NewCommand::TEMPLATE_REPO_URL
    refute_path_exists repo_file("templates", "ruflet_flutter_template")
  end

  def test_template_root_accepts_the_external_repository_directory
    Dir.mktmpdir do |root|
      template = File.join(root, "templates", "ruflet_flutter_template")
      FileUtils.mkdir_p(File.join(template, "lib"))
      File.write(File.join(template, "pubspec.yaml"), "name: ruflet_client\n")
      File.write(File.join(template, "lib", "main.dart"), "void main() {}\n")

      previous = ENV["RUFLET_TEMPLATE_ROOT"]
      ENV["RUFLET_TEMPLATE_ROOT"] = root
      assert_equal template, Ruflet::CLI.send(:resolve_ruflet_client_template_root)
    ensure
      ENV["RUFLET_TEMPLATE_ROOT"] = previous
    end
  end

  def test_explorer_android_builds_declare_every_service_permission
    expected_permissions = Ruflet::CLI::BuildCommand::ANDROID_SERVICE_PERMISSIONS.values.flatten.uniq

    EXPLORER_CONFIG_DIRS.each do |directory|
      manifest = File.read(repo_file(directory, "android/app/src/main/AndroidManifest.xml"))

      expected_permissions.each do |permission|
        assert_includes manifest, %(android:name="#{permission}"), "#{directory}: #{permission}"
      end
    end
  end

  def test_explorer_ios_builds_declare_every_service_usage_description
    expected_keys = Ruflet::CLI::BuildCommand::IOS_SERVICE_USAGE_KEYS.values

    EXPLORER_CONFIG_DIRS.each do |directory|
      plist = File.read(repo_file(directory, "ios/Runner/Info.plist"))

      expected_keys.each do |key|
        assert_includes plist, "<key>#{key}</key>", "#{directory}: #{key}"
      end
    end
  end

  private

  def repo_file(directory, path)
    File.join(REPOSITORY_ROOT, directory, path)
  end
end
