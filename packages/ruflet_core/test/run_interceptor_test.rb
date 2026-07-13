# frozen_string_literal: true

require_relative "test_helper"

class RufletRunInterceptorTest < Minitest::Test
  def test_run_short_circuits_when_interceptor_handles_execution
    executed = false
    interceptor = lambda do |entrypoint:, host:, port:|
      assert_equal "127.0.0.1", host
      assert_equal 9999, port
      assert entrypoint.respond_to?(:call)
      { "captured" => true }
    end

    result = Ruflet.with_run_interceptor(interceptor) do
      Ruflet.run(host: "127.0.0.1", port: 9999) { executed = true }
    end

    assert_equal({ "captured" => true }, result)
    refute executed
  end

  def test_last_registered_interceptor_has_priority
    order = []
    first = ->(**) { order << :first; :pass }
    second = ->(**) { order << :second; :handled }

    result = Ruflet.with_run_interceptor(first) do
      Ruflet.with_run_interceptor(second) do
        Ruflet.run { nil }
      end
    end

    assert_equal :handled, result
    assert_equal [:second], order
  end

  def test_run_preserves_zero_port_from_environment
    previous = ENV["RUFLET_PORT"]
    ENV["RUFLET_PORT"] = "0"
    captured_port = nil
    interceptor = lambda do |entrypoint:, host:, port:|
      captured_port = port
      :handled
    end

    Ruflet.with_run_interceptor(interceptor) { Ruflet.run { nil } }

    assert_equal 0, captured_port
  ensure
    ENV["RUFLET_PORT"] = previous
  end
end
