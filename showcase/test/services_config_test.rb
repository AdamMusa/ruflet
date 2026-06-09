# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class ServicesConfigTest < Minitest::Test
  REQUIRED_SERVICE_PATTERNS = {
    "accelerometer" => /page\.accelerometer\(/,
    "audio" => /page\.audio\(/,
    "audio_recorder" => /page\.audio_recorder\(/,
    "barometer" => /page\.barometer\(/,
    "battery" => /page\.battery\(/,
    "browser_context_menu" => /page\.browser_context_menu\(/,
    "camera" => /page\.camera\(/,
    "charts" => /bar_chart\(/,
    "clipboard" => /page\.clipboard\b/,
    "connectivity" => /page\.connectivity\(/,
    "file_picker" => /page\.file_picker\b/,
    "flashlight" => /page\.service\(\s*:flashlight/,
    "geolocator" => /page\.geolocator\(/,
    "map" => /\bmap\(/,
    "gyroscope" => /page\.gyroscope\(/,
    "magnetometer" => /page\.magnetometer\(/,
    "permission_handler" => /page\.permission_handler\(/,
    "screen_brightness" => /page\.screen_brightness\b/,
    "screenshot" => /page\.screenshot\(/,
    "secure_storage" => /page\.secure_storage\(/,
    "semantics_service" => /page\.semantics_service\(/,
    "shake_detector" => /page\.shake_detector\(/,
    "share" => /page\.share(?:\b|_)/,
    "storage_paths" => /page\.storage_paths\b/,
    "user_accelerometer" => /page\.user_accelerometer\(/,
    "video" => /\bvideo\(/,
    "webview" => /\bweb_view\(/,
    "window" => /page\.window\(/
  }.freeze

  def test_ruflet_yaml_lists_every_service_used_by_showcase
    source = studio_source
    configured_services = Array(ruflet_config.fetch("services")).map(&:to_s)

    REQUIRED_SERVICE_PATTERNS.each do |service, pattern|
      next unless source.match?(pattern)

      assert_includes configured_services, service
    end
  end

  private

  def ruflet_config
    YAML.safe_load(File.read(File.expand_path("../ruflet.yaml", __dir__)), aliases: true)
  end

  def studio_source
    root = File.expand_path("..", __dir__)
    Dir[File.join(root, "**", "*.rb")]
      .reject { |path| path.include?("#{File::SEPARATOR}build#{File::SEPARATOR}") }
      .sort
      .map { |path| File.read(path) }
      .join("\n")
  end
end
