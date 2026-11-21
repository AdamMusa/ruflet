# frozen_string_literal: true

require_relative "test_helper"
require "socket"
require "stringio"

# The Rails endpoint checks the handshake's Origin. Until the app configures
# allowed origins it still accepts a foreign one, as before, and logs it once;
# once configured, it refuses other foreign origins before hijacking.
class RufletRailsWebSocketOriginTest < Minitest::Test
  def setup
    @previous_allowed = Ruflet::Rails.config.allowed_origins
    @previous_env = ENV["RUFLET_ALLOWED_ORIGINS"]
    ENV.delete("RUFLET_ALLOWED_ORIGINS")
    Ruflet::Rails.config.allowed_origins = nil
    @log = StringIO.new
    @original_stderr = $stderr
    $stderr = @log
    @sockets = []
  end

  def teardown
    $stderr = @original_stderr
    Ruflet::Rails.config.allowed_origins = @previous_allowed
    @previous_env.nil? ? ENV.delete("RUFLET_ALLOWED_ORIGINS") : ENV["RUFLET_ALLOWED_ORIGINS"] = @previous_env
    @sockets.each { |socket| socket.close rescue nil }
  end

  def test_a_foreign_origin_is_still_accepted_and_logged_once_by_default
    endpoint = build_endpoint

    2.times do
      status, handshake = upgrade(endpoint, origin: "https://evil.example")
      assert_equal(-1, status)
      assert_includes handshake, "101 Switching Protocols"
    end

    assert_equal 1, @log.string.scan('accepted a WebSocket connection from Origin "https://evil.example"').size
    assert_includes @log.string, "Ruflet::Rails.config.allowed_origins"
  end

  def test_the_app_s_own_origin_and_native_clients_pass_silently
    endpoint = build_endpoint

    assert_equal(-1, upgrade(endpoint, origin: "https://myapp.example").first)
    assert_equal(-1, upgrade(endpoint, origin: nil).first)
    assert_equal(-1, upgrade(endpoint, origin: "https://myapp.example", host: "127.0.0.1:3000",
                                       forwarded_host: "myapp.example").first)
    assert_equal(-1, upgrade(endpoint, origin: "http://localhost:3000", host: "localhost:3000").first)
    refute_includes @log.string, "WebSocket connection from Origin"
  end

  def test_configured_allowed_origins_refuse_other_foreign_origins
    Ruflet::Rails.config.allowed_origins = %w[https://app.example.com]
    endpoint = build_endpoint

    hijacked = false
    status, headers, body = endpoint.call(env_for(origin: "https://evil.example", on_hijack: -> { hijacked = true }))
    assert_equal 403, status
    assert_equal "text/plain", headers["content-type"]
    assert_equal ["Origin not allowed"], body
    refute hijacked, "a refused upgrade is never hijacked"
    assert_includes @log.string, "add https://evil.example to Ruflet::Rails.config.allowed_origins"

    assert_equal(-1, upgrade(endpoint, origin: "https://app.example.com").first)
    assert_equal(-1, upgrade(endpoint, origin: "https://myapp.example").first)
    assert_equal(-1, upgrade(endpoint, origin: nil).first)
  end

  def test_the_environment_variable_configures_the_endpoint_too
    ENV["RUFLET_ALLOWED_ORIGINS"] = "https://app.example.com"
    endpoint = build_endpoint

    assert_equal 403, endpoint.call(env_for(origin: "https://evil.example")).first
    assert_equal(-1, upgrade(endpoint, origin: "https://app.example.com").first)
  end

  def test_a_wildcard_accepts_every_origin_without_logging
    Ruflet::Rails.config.allowed_origins = "*"
    endpoint = build_endpoint

    assert_equal(-1, upgrade(endpoint, origin: "https://evil.example").first)
    refute_includes @log.string, "WebSocket connection from Origin"
  end

  private

  def build_endpoint
    Ruflet::Rails::Protocol::Runner.new do |page|
      page.add(Ruflet::UI::ControlFactory.build(:text, value: "hello"))
    end.build_endpoint(path: "/ws")
  end

  def env_for(origin:, host: "myapp.example", forwarded_host: nil, io: nil, on_hijack: -> {})
    env = {
      "REQUEST_METHOD" => "GET", "PATH_INFO" => "/ws", "HTTP_HOST" => host,
      "HTTP_UPGRADE" => "websocket", "HTTP_CONNECTION" => "Upgrade",
      "HTTP_SEC_WEBSOCKET_KEY" => "dGhlIHNhbXBsZSBub25jZQ==", "HTTP_SEC_WEBSOCKET_VERSION" => "13",
      "rack.hijack" => on_hijack, "rack.hijack_io" => io
    }
    env["HTTP_ORIGIN"] = origin if origin
    env["HTTP_X_FORWARDED_HOST"] = forwarded_host if forwarded_host
    env
  end

  def upgrade(endpoint, **options)
    server_io, client_io = UNIXSocket.pair
    @sockets << server_io << client_io
    status, = endpoint.call(env_for(io: server_io, **options))
    return [status, ""] unless status == -1

    response = +""
    response << client_io.readpartial(1024) until response.include?("\r\n\r\n")
    [status, response]
  end
end
