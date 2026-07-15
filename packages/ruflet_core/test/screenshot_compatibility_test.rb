# frozen_string_literal: true

require_relative "test_helper"

class RufletScreenshotCompatibilityTest < Minitest::Test
  def test_screenshot_accepts_positional_content_and_serializes_current_flet_props
    control = Ruflet.screenshot(
      Ruflet.text("Capture me"),
      disabled: true,
      tooltip: "Capture area",
      visible: true
    )

    patch = control.to_patch

    assert_equal "Screenshot", patch["_c"]
    assert_equal "Text", patch["content"]["_c"]
    assert_equal true, patch["disabled"]
    assert_equal "Capture area", patch["tooltip"]
    assert_equal true, patch["visible"]
  end

  def test_screenshot_requires_content_like_flet
    error = assert_raises(ArgumentError) { Ruflet.screenshot }

    assert_match(/content/, error.message)
  end
end
