# frozen_string_literal: true

require "minitest/autorun"

require_relative "../helpers"

# Native showcase demos must guard features the current platform cannot run,
# so the user sees a clean notice instead of a raw "not supported" exception.
class FeatureGuardTest < Minitest::Test
  include Showcase::Helpers

  Page = Struct.new(:client_details)

  def page_for(platform)
    Page.new({ "platform" => platform })
  end

  def test_directory_picker_only_blocked_on_web
    refute feature_supported?(page_for("web"), "directory_picker")
    assert feature_supported?(page_for("macos"), "directory_picker")
    assert feature_supported?(page_for("windows"), "directory_picker")
    assert feature_supported?(page_for("ios"), "directory_picker")
  end

  def test_battery_only_on_mobile
    refute feature_supported?(page_for("web"), "battery")
    refute feature_supported?(page_for("macos"), "battery")
    refute feature_supported?(page_for("linux"), "battery")
    assert feature_supported?(page_for("android"), "battery")
    assert feature_supported?(page_for("ios"), "battery")
  end

  def test_webview_blocked_on_web_only
    refute feature_supported?(page_for("web"), "webview")
    assert feature_supported?(page_for("macos"), "webview")
    assert feature_supported?(page_for("android"), "webview")
  end

  def test_sensors_are_mobile_only
    %w[accelerometer gyroscope magnetometer barometer user_accelerometer shake_detector].each do |sensor|
      refute feature_supported?(page_for("web"), sensor), "#{sensor} should be blocked on web"
      refute feature_supported?(page_for("macos"), sensor), "#{sensor} should be blocked on desktop"
      assert feature_supported?(page_for("ios"), sensor), "#{sensor} should work on mobile"
    end
  end

  def test_unknown_platform_does_not_hide_anything
    blank = Page.new({ "platform" => "" })
    assert feature_supported?(blank, "battery")
    assert feature_supported?(blank, "webview")
  end

  def test_unmapped_feature_is_always_supported
    assert feature_supported?(page_for("web"), "clipboard")
    assert feature_supported?(page_for("macos"), "totally_unknown_feature")
  end
end
