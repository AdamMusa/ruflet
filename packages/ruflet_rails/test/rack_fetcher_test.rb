# frozen_string_literal: true

require_relative "test_helper"

# Screens are dispatched into the Rack app in-process. A screen may therefore be
# named by path alone — nothing here goes over the network, so there is no host
# to know. Rails still reads Host off the env, so the fetcher has to supply one
# the app will accept.
class RufletRackFetcherTest < Minitest::Test
  # Records the env it was called with and answers a fixed response.
  class StubRackApp
    attr_reader :envs

    def initialize(status: 200, headers: {}, body: "<text>ok</text>")
      @status = status
      @headers = headers
      @body = body
      @envs = []
    end

    def call(env)
      @envs << env
      [@status, @headers, [@body]]
    end
  end

  def teardown
    Ruflet::Rails.config.backend_url = nil
  end

  def fetch(app, url, base_url: nil, env: nil, method: "GET", **kwargs)
    fetcher = Ruflet::Rails::HtmlDsl::RackFetcher.new(app: app, base_url: base_url)
    if env
      Ruflet::Rails::Protocol::Context.with_env(env) { fetcher.fetch(method, url, **kwargs) }
    else
      fetcher.fetch(method, url, **kwargs)
    end
  end

  def ws_env(host, scheme: "http")
    { "HTTP_HOST" => host, "rack.url_scheme" => scheme }
  end

  def test_path_url_takes_its_host_from_the_live_websocket_connection
    app = StubRackApp.new
    fetch(app, "/native", env: ws_env("192.168.1.50:3000"))

    env = app.envs.first
    assert_equal "/native", env["PATH_INFO"]
    assert_equal "192.168.1.50:3000", env["HTTP_HOST"]
    assert_equal "192.168.1.50", env["SERVER_NAME"]
    assert_equal "3000", env["SERVER_PORT"]
    assert_equal "http", env["rack.url_scheme"]
  end

  def test_path_url_honours_the_forwarded_host_and_scheme
    app = StubRackApp.new
    fetch(app, "/native", env: { "HTTP_X_FORWARDED_HOST" => "app.example.com",
                                 "HTTP_X_FORWARDED_PROTO" => "https,http",
                                 "HTTP_HOST" => "internal:3000" })

    env = app.envs.first
    assert_equal "app.example.com", env["HTTP_HOST"]
    assert_equal "https", env["rack.url_scheme"]
    assert_equal "443", env["SERVER_PORT"]
  end

  def test_path_url_falls_back_to_the_configured_backend_url_off_connection
    Ruflet::Rails.config.backend_url = "https://configured.example.com/"
    app = StubRackApp.new
    fetch(app, "/native")

    assert_equal "configured.example.com", app.envs.first["HTTP_HOST"]
    assert_equal "https", app.envs.first["rack.url_scheme"]
  end

  def test_the_live_connection_wins_over_a_stale_configured_backend_url
    Ruflet::Rails.config.backend_url = "http://127.0.0.1:3000"
    app = StubRackApp.new
    fetch(app, "/native", env: ws_env("192.168.1.50:3000"))

    assert_equal "192.168.1.50:3000", app.envs.first["HTTP_HOST"]
  end

  def test_path_url_falls_back_to_localhost_with_no_connection_and_no_config
    app = StubRackApp.new
    fetch(app, "/native")

    assert_equal "localhost", app.envs.first["HTTP_HOST"]
  end

  def test_an_explicit_base_url_overrides_everything
    Ruflet::Rails.config.backend_url = "http://127.0.0.1:3000"
    app = StubRackApp.new
    fetch(app, "/native", base_url: "http://explicit.test", env: ws_env("192.168.1.50:3000"))

    assert_equal "explicit.test", app.envs.first["HTTP_HOST"]
  end

  def test_an_absolute_url_is_used_verbatim_and_ignores_the_connection
    app = StubRackApp.new
    fetch(app, "https://given.example.com/native", env: ws_env("192.168.1.50:3000"))

    env = app.envs.first
    assert_equal "given.example.com", env["HTTP_HOST"]
    assert_equal "https", env["rack.url_scheme"]
    assert_equal "/native", env["PATH_INFO"]
  end

  def test_the_response_reports_the_resolved_absolute_url
    response = fetch(StubRackApp.new, "/native", env: ws_env("192.168.1.50:3000"))

    assert_equal "http://192.168.1.50:3000/native", response.url
  end

  def test_a_path_url_still_follows_redirects
    app = Object.new
    app.define_singleton_method(:envs) { @envs ||= [] }
    app.define_singleton_method(:call) do |env|
      envs << env
      if envs.length == 1
        [302, { "location" => "/native/counter" }, [""]]
      else
        [200, {}, ["<text>done</text>"]]
      end
    end

    response = fetch(app, "/native", env: ws_env("192.168.1.50:3000"))

    assert_equal 200, response.status
    assert_equal ["/native", "/native/counter"], app.envs.map { |e| e["PATH_INFO"] }
    assert_equal ["192.168.1.50:3000", "192.168.1.50:3000"], app.envs.map { |e| e["HTTP_HOST"] }
  end

  def test_query_strings_and_params_survive_path_resolution
    app = StubRackApp.new
    fetch(app, "/search?scope=all", env: ws_env("host.test"), params: { "q" => "ada" })

    env = app.envs.first
    assert_equal "/search", env["PATH_INFO"]
    assert_includes env["QUERY_STRING"], "scope=all"
    assert_includes env["QUERY_STRING"], "q=ada"
  end

  def test_post_params_become_a_form_encoded_body
    app = StubRackApp.new
    fetch(app, "/native/form", method: "POST", env: ws_env("host.test"),
                               params: { "name" => "Ada Lovelace" })

    env = app.envs.first
    assert_equal "POST", env["REQUEST_METHOD"]
    assert_equal "application/x-www-form-urlencoded", env["CONTENT_TYPE"]
    assert_equal "name=Ada+Lovelace", env["rack.input"].read
  end

  def test_it_marks_the_request_as_a_native_one
    app = StubRackApp.new
    fetch(app, "/native", env: ws_env("host.test"))

    assert_equal "1", app.envs.first["HTTP_X_RUFLET_NATIVE"]
  end
end
