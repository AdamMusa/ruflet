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
end
