# frozen_string_literal: true

require_relative "test_helper"

class RufletCliTemplatesTest < Minitest::Test
  REPOSITORY_ROOT = File.expand_path("../../..", __dir__)
  EXPLORER_CONFIG_DIRS = %w[ruflet_client templates/ruflet_flutter_template].freeze
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

  def test_explorer_configs_enable_every_extension_and_protected_service
    expected_extensions = Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP.keys.sort
    expected_services = Ruflet::CLI::BuildCommand::PROTECTED_SERVICE_EXTENSIONS.keys.sort

    EXPLORER_CONFIG_DIRS.each do |directory|
      config = YAML.safe_load(File.read(repo_file(directory, "ruflet.yaml")))
      services = YAML.safe_load(File.read(repo_file(directory, "services.yaml")))
      service_names = services.fetch("services").map { |entry| entry.keys.fetch(0) }

      assert_equal expected_extensions, config.fetch("extensions").sort, directory
      assert_equal expected_services, service_names.sort, directory
    end
  end

  def test_reusable_explorer_registers_every_optional_extension
    expected_extensions = Ruflet::CLI::BuildCommand::CLIENT_EXTENSION_MAP.keys.sort
    source = File.read(repo_file("ruflet_client", "lib/main.dart"))

    assert_equal expected_extensions, EXPLORER_EXTENSION_REGISTRATIONS.keys.sort
    EXPLORER_EXTENSION_REGISTRATIONS.each do |extension, registration|
      assert_includes source, registration, extension
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
