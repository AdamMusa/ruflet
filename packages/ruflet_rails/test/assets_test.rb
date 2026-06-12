# frozen_string_literal: true

require_relative "test_helper"

# Ruflet::Rails.asset_url turns a Rails asset into an absolute URL the Flutter
# client can load over HTTP (for image(src:)). The path comes from the asset
# pipeline; the host from an explicit arg, config.backend_url, or the live
# request host.
class RufletAssetsTest < Minitest::Test
  def setup
    @prev_backend = Ruflet::Rails.config.backend_url
    Ruflet::Rails.config.backend_url = nil
  end

  def teardown
    Ruflet::Rails.config.backend_url = @prev_backend
  end

  def test_absolute_urls_pass_through_untouched
    url = "https://cdn.example.com/logo.png"
    assert_equal url, Ruflet::Rails.asset_url(url)
  end

  def test_explicit_host_builds_an_absolute_url
    result = Ruflet::Rails.asset_url("logo.png", host: "http://192.168.1.10:3100")
    assert result.start_with?("http://192.168.1.10:3100/"), result
    assert_includes result, "logo"
  end

  def test_trailing_slash_on_host_does_not_double_up
    result = Ruflet::Rails.asset_url("logo.png", host: "http://h:3100/")
    refute_includes result, "3100//"
    assert result.start_with?("http://h:3100/"), result
  end

  def test_config_backend_url_supplies_the_host
    Ruflet::Rails.config.backend_url = "https://app.example.com"
    result = Ruflet::Rails.asset_url("logo.png")
    assert result.start_with?("https://app.example.com/"), result
  end

  def test_explicit_host_wins_over_config
    Ruflet::Rails.config.backend_url = "https://config.example.com"
    result = Ruflet::Rails.asset_url("logo.png", host: "http://explicit:3100")
    assert result.start_with?("http://explicit:3100/"), result
  end

  def test_host_falls_back_to_the_live_request
    env = { "HTTP_HOST" => "10.0.0.5:3100", "rack.url_scheme" => "http" }
    result = Ruflet::Rails::Protocol::Context.with_env(env) do
      Ruflet::Rails.asset_url("logo.png")
    end
    assert result.start_with?("http://10.0.0.5:3100/"), result
  end

  def test_forwarded_headers_are_respected
    env = { "HTTP_X_FORWARDED_HOST" => "public.example.com", "HTTP_X_FORWARDED_PROTO" => "https" }
    result = Ruflet::Rails::Protocol::Context.with_env(env) do
      Ruflet::Rails.asset_url("logo.png")
    end
    assert result.start_with?("https://public.example.com/"), result
  end

  def test_without_any_host_a_relative_path_is_returned
    # No explicit host, no backend_url, no request env.
    result = Ruflet::Rails.asset_url("logo.png")
    assert result.start_with?("/"), result
    assert_includes result, "logo"
  end

  def test_image_url_is_an_alias
    a = Ruflet::Rails.asset_url("logo.png", host: "http://h")
    b = Ruflet::Rails.image_url("logo.png", host: "http://h")
    assert_equal a, b
  end

  def test_helpers_are_not_publicly_exposed
    refute_respond_to Ruflet::Rails, :request_base_url
    refute_respond_to Ruflet::Rails, :asset_pipeline_path
  end

  # --- backend_url: the always-resolving base URL --------------------------

  def test_backend_url_uses_explicit_host_then_config_then_request
    assert_equal "http://explicit:3100", Ruflet::Rails.backend_url(host: "http://explicit:3100/")

    Ruflet::Rails.config.backend_url = "https://app.example.com/"
    assert_equal "https://app.example.com", Ruflet::Rails.backend_url
    Ruflet::Rails.config.backend_url = nil

    env = { "HTTP_HOST" => "10.0.0.5:3100", "rack.url_scheme" => "http" }
    resolved = Ruflet::Rails::Protocol::Context.with_env(env) { Ruflet::Rails.backend_url }
    assert_equal "http://10.0.0.5:3100", resolved
  end

  def test_backend_url_is_blank_only_when_nothing_is_available
    # No explicit host, no config, no request (e.g. a build) — caller must set
    # config.backend_url to cover this.
    assert_equal "", Ruflet::Rails.backend_url
  end
end
