# frozen_string_literal: true

require_relative "test_helper"

class RufletViewHelpersTest < Minitest::Test
  def helper
    @helper ||= Class.new { include Ruflet::Rails::ViewHelpers }.new
  end

  def test_renders_an_iframe_to_the_mount_route
    html = helper.ruflet_frame("/products").to_s
    assert_includes html, "<iframe"
    assert_includes html, 'src="/products"'
    assert_includes html, 'title="Ruflet"'
    assert_includes html, 'loading="lazy"'
    assert_includes html, "</iframe>"
  end

  def test_numeric_dimensions_become_pixels_strings_pass_through
    html = helper.ruflet_frame("/showcase", height: 640, width: "80vw").to_s
    assert_includes html, "height:640px;"
    assert_includes html, "width:80vw;"
    assert_includes html, "border:0;"
  end

  def test_extra_attributes_underscores_become_dashes
    html = helper.ruflet_frame("/products", allow: "clipboard-read", data_role: "embed").to_s
    assert_includes html, 'allow="clipboard-read"'
    assert_includes html, 'data-role="embed"'
  end

  def test_extra_style_is_appended
    html = helper.ruflet_frame("/products", style: "border-radius:8px;").to_s
    assert_includes html, "border:0;"
    assert_includes html, "border-radius:8px;"
  end

  def test_attribute_values_are_html_escaped
    html = helper.ruflet_frame('/x"><script>alert(1)</script>').to_s
    refute_includes html, "<script>alert(1)</script>"
    assert_includes html, "&lt;script&gt;"
  end

  def test_full_urls_pass_through_for_cross_origin_embeds
    html = helper.ruflet_frame("https://other.example/app").to_s
    assert_includes html, 'src="https://other.example/app"'
  end
end
