# frozen_string_literal: true

require_relative "test_helper"

class RufletServerRunInterceptorTest < Minitest::Test
  def test_server_run_still_honors_core_run_interceptors
    executed = false
    interceptor = lambda do |entrypoint:, host:, port:|
      assert_equal "127.0.0.1", host
      assert_equal 4555, port
      assert entrypoint.respond_to?(:call)
      :rails_mount
    end

    result = Ruflet.with_run_interceptor(interceptor) do
      Ruflet.run(host: "127.0.0.1", port: 4555) { executed = true }
    end

    assert_equal :rails_mount, result
    refute executed
  end

  def test_server_run_uses_ruflet_port_env_when_port_not_explicit
    previous = ENV["RUFLET_PORT"]
    ENV["RUFLET_PORT"] = "8560"
    interceptor = lambda do |entrypoint:, host:, port:|
      assert_equal "0.0.0.0", host
      assert_equal 8560, port
      assert entrypoint.respond_to?(:call)
      :captured
    end

    result = Ruflet.with_run_interceptor(interceptor) do
      Ruflet.run { nil }
    end

    assert_equal :captured, result
  ensure
    ENV["RUFLET_PORT"] = previous
  end
end
