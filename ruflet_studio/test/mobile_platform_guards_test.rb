# frozen_string_literal: true

require "minitest/autorun"

class MobilePlatformGuardsTest < Minitest::Test
  MOBILE_ONLY_FILES = %w[
    sections_media/accelerometer.rb
    sections_media/gyroscope.rb
    sections_media/user_accelerometer.rb
    sections_media/magnetometer.rb
    sections_media/barometer.rb
    sections_media/shake_detector.rb
    sections_media/flashlight.rb
    sections_media/camera.rb
  ].freeze

  def test_helpers_expose_mobile_platform_check
    helpers = File.read(File.expand_path("../helpers.rb", __dir__))

    assert_includes helpers, "def mobile_platform?(page)"
    assert_includes helpers, "%w[ios android].include?(client_platform(page))"
    assert_includes helpers, "def permission_handler_platform?(page)"
    assert_includes helpers, "%w[ios android windows web].include?(client_platform(page))"
  end

  def test_mobile_only_samples_check_platform_before_registering_services
    MOBILE_ONLY_FILES.each do |relative_path|
      source = File.read(File.expand_path("../#{relative_path}", __dir__))

      assert_includes source, "mobile_platform?(page)", "#{relative_path} must check platform before service use"
    end
  end

  def test_barometer_does_not_start_sensor_stream_on_route_entry
    source = File.read(File.expand_path("../sections_media/barometer.rb", __dir__))

    assert_match(/page\.barometer\(\s*interval: 200,\s*enabled: false,/m, source)
  end
end
